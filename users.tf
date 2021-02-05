resource "aws_iam_user" "users"{
    for_each = var.iam_users
    name = each.value 
    force_destroy = true
}

resource "aws_iam_user_policy_attachment" "attach_iam_users_policies" {
  for_each = var.iam_users_policies
  user       = aws_iam_user.users[each.value.iam_user].name
  policy_arn = each.value.policy

  depends_on = [ aws_iam_user.users ]
}

