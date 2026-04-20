Here is a clear English response you can send:

You are correct: if my service account cannot be granted any role containing container.clusters.create in that project, then I cannot create my own GKE cluster in that project, even in a different region. GKE cluster creation is authorized at the project level, not per individual cluster or per region.

The key point is that this does not require roles/container.clusterAdmin specifically. It requires the permission container.clusters.create on the project. That permission can come either from a predefined role or from a custom IAM role. If no such permission can be granted, cluster creation is not possible in that project.

Also, GKE IAM permissions apply across all clusters in the project. Google Cloud does not provide a standard IAM mechanism to allow creation or management for only one specific GKE cluster inside the same project.

Conclusion:
If security or ownership rules prevent granting container.clusters.create in this project because another external/managed cluster already exists there, then the practical and clean solution is to create your custom GKE cluster in a separate project. That is the safest way to keep full isolation and avoid impacting the existing managed cluster.

If you want, I can also turn this into an even shorter email-style recommendation for management or platform teams.
