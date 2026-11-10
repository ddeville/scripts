// Package tailscalestatus adapts the native Tailscale client for desktop status consumers.
package tailscalestatus

import (
	"cmp"
	"context"
	"fmt"
	"net/netip"
	"slices"
	"strings"
	"time"

	"tailscale.com/client/local"
	"tailscale.com/ipn"
	"tailscale.com/ipn/ipnstate"
)

const requestTimeout = 5 * time.Second

type snapshot struct {
	Available bool      `json:"available"`
	Backend   string    `json:"backend"`
	Connected bool      `json:"connected"`
	Account   string    `json:"account"`
	Tailnet   string    `json:"tailnet"`
	Device    string    `json:"device"`
	Address   string    `json:"address"`
	AuthURL   string    `json:"authUrl"`
	ExitNode  *peer     `json:"exitNode"`
	ExitNodes []peer    `json:"exitNodes"`
	Peers     []peer    `json:"peers"`
	Profiles  []profile `json:"profiles"`
	Health    []string  `json:"health"`
	Error     string    `json:"error"`
}

type peer struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Address  string `json:"address"`
	Online   bool   `json:"online"`
	Location string `json:"location"`
}

type profile struct {
	ID       string `json:"id"`
	Nickname string `json:"nickname"`
	Tailnet  string `json:"tailnet"`
	Account  string `json:"account"`
	Selected bool   `json:"selected"`
}

func emptySnapshot() snapshot {
	return snapshot{
		Backend:   "Unavailable",
		ExitNodes: []peer{},
		Peers:     []peer{},
		Profiles:  []profile{},
		Health:    []string{},
	}
}

func collect(ctx context.Context, client *local.Client) (snapshot, error) {
	ctx, cancel := context.WithTimeout(ctx, requestTimeout)
	defer cancel()

	status, err := client.Status(ctx)
	if err != nil {
		return snapshot{}, fmt.Errorf("read Tailscale status: %w", err)
	}

	current, profiles, err := client.ProfileStatus(ctx)
	if err != nil {
		return snapshot{}, fmt.Errorf("read Tailscale profiles: %w", err)
	}

	return normalize(status, current, profiles), nil
}

func normalize(status *ipnstate.Status, current ipn.LoginProfile, profiles []ipn.LoginProfile) snapshot {
	data := emptySnapshot()
	data.Available = true
	data.Backend = cmp.Or(status.BackendState, "NoState")
	data.Connected = status.BackendState == "Running"
	data.Address = firstAddress(status.TailscaleIPs)
	data.AuthURL = status.AuthURL

	if status.Self != nil {
		data.Device = status.Self.HostName
		data.Account = status.User[status.Self.UserID].LoginName
	}

	if status.CurrentTailnet != nil {
		data.Tailnet = status.CurrentTailnet.Name
	}

	for _, p := range profiles {
		item := profile{
			ID:       string(p.ID),
			Nickname: p.Name,
			Account:  p.UserProfile.LoginName,
			Tailnet:  p.NetworkProfile.DisplayNameOrDefault(),
			Selected: p.ID == current.ID,
		}
		data.Profiles = append(data.Profiles, item)

		if item.Selected {
			data.Account = cmp.Or(item.Account, data.Account)
			data.Tailnet = cmp.Or(item.Tailnet, data.Tailnet)
		}
	}

	for _, p := range status.Peer {
		item := peerDetails(p)
		data.Peers = append(data.Peers, item)

		if p.ExitNodeOption {
			data.ExitNodes = append(data.ExitNodes, item)
		}

		if status.ExitNodeStatus != nil && p.ID == status.ExitNodeStatus.ID {
			data.ExitNode = &item
		}
	}

	if exit := status.ExitNodeStatus; exit != nil && exit.ID != "" {
		if data.ExitNode == nil {
			data.ExitNode = &peer{ID: string(exit.ID)}
		}

		data.ExitNode.Online = exit.Online
		data.ExitNode.Address = ""

		if len(exit.TailscaleIPs) > 0 {
			data.ExitNode.Address = exit.TailscaleIPs[0].Addr().String()
		}

		data.ExitNode.Name = cmp.Or(data.ExitNode.Name, data.ExitNode.Address, "Exit node")
	}

	slices.SortFunc(data.Peers, comparePeers)
	slices.SortFunc(data.ExitNodes, func(a, b peer) int {
		if a.Online != b.Online {
			return comparePeers(a, b)
		}

		return cmp.Or(cmp.Compare(a.Location, b.Location), comparePeers(a, b))
	})

	// Stopped clients can retain health warnings from the previous connection.
	if data.Connected {
		data.Health = append(data.Health, status.Health...)
	}

	return data
}

func peerDetails(p *ipnstate.PeerStatus) peer {
	item := peer{
		ID:      string(p.ID),
		Name:    cmp.Or(p.HostName, strings.TrimRight(p.DNSName, ".")),
		Address: firstAddress(p.TailscaleIPs),
		Online:  p.Online,
	}

	if location := p.Location; location != nil {
		parts := []string{location.Country, location.City}
		parts = slices.DeleteFunc(parts, func(part string) bool { return part == "" })
		item.Location = strings.Join(parts, " · ")
	}

	return item
}

func firstAddress(addresses []netip.Addr) string {
	if len(addresses) == 0 {
		return ""
	}

	return addresses[0].String()
}

func comparePeers(a, b peer) int {
	if a.Online != b.Online {
		if a.Online {
			return -1
		}

		return 1
	}

	return cmp.Or(cmp.Compare(strings.ToLower(a.Name), strings.ToLower(b.Name)), cmp.Compare(a.ID, b.ID))
}
