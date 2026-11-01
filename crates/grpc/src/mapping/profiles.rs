use kumo_application::profiles::ProfileView;
use kumo_proto::v1 as pb;

pub fn profile_to(view: &ProfileView) -> pb::Profile {
    let (p, a) = (&view.profile, &view.activity);
    pb::Profile {
        id: p.id.to_string(),
        name: p.name.clone(),
        color: p.color.clone(),
        position: p.position,
        worktrees_dir: p.worktrees_dir.clone(),
        git_name: p.git_name.clone(),
        git_email: p.git_email.clone(),
        is_default: p.is_default(),
        agents_running: a.agents_running,
        agents_waiting: a.agents_waiting,
        terminals_open: a.terminals_open,
        namespaces: a.namespaces,
        repos: a.repos,
    }
}

pub fn profile_list_to(views: &[ProfileView]) -> pb::ProfileList {
    pb::ProfileList {
        profiles: views.iter().map(profile_to).collect(),
    }
}
