package llm

// SelectModel chooses an appropriate model based on request hints and configuration.
// Priority:
// 1) Exact modelId if provided and enabled
// 2) First enabled model under providerHint
// 3) First enabled model globally
func SelectModel(req ChatRequest) (ModelInfo, bool) {
	ms := Models()

	// Try explicit modelId
	if req.ModelID != "" {
		for _, m := range ms {
			if m.ModelID == req.ModelID && m.Status != "disabled" {
				return m, true
			}
		}
	}

	// Try providerHint
	if req.ProviderHint != "" {
		for _, m := range ms {
			if m.ProviderID == req.ProviderHint && m.Status != "disabled" {
				return m, true
			}
		}
	}

	// Fallback to first enabled globally
	for _, m := range ms {
		if m.Status != "disabled" {
			return m, true
		}
	}
	return ModelInfo{}, false
}
