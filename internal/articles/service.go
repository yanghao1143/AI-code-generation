package articles

// Service provides business operations on articles, delegating to a repository.
type Service struct {
    repo Repository
}

func NewService(repo Repository) *Service { return &Service{repo: repo} }

func (s *Service) List() []Article                                     { return s.repo.List() }
func (s *Service) Get(id string) (Article, bool)                       { return s.repo.Get(id) }
func (s *Service) Create(req CreateRequest) Article                    { return s.repo.Create(req) }
func (s *Service) Update(id string, req UpdateRequest) (Article, bool) { return s.repo.Update(id, req) }
func (s *Service) Delete(id string) bool                               { return s.repo.Delete(id) }
func (s *Service) Count() int                                          { return s.repo.Count() }
