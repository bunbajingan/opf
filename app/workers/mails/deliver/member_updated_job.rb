#-- encoding: UTF-8
#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2021 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See docs/COPYRIGHT.rdoc for more details.
#++

class Mails::Deliver::MemberUpdatedJob < ApplicationJob
  def perform(current_user:,
              member:)
    if member.project.nil?
      MemberMailer
        .updated_global(current_user, member)
        .deliver_now
    elsif member.principal.is_a?(Group)
      Member
        .where(project: member.project,
               principal: member.principal.users)
        .includes(:project, :principal, :roles)
        .each do |users_member|
        MemberMailer
          .added_project(current_user, users_member)
          .deliver_now
      end
    elsif member.principal.is_a?(User)
      MemberMailer
        .updated_project(current_user, member)
        .deliver_now
    end
  end
end
