define [
	"base"
], (App) ->
	App.directive "emailOrOrcid", () ->
		restrict: "A"
		require: "ngModel"
		link: (scope, elm, attrs, ctrl) ->
			email_validator = ctrl.$validators.email

			# From http://support.orcid.org/knowledgebase/articles/116780-structure-of-the-orcid-identifier
			is_valid_checksum = (orcid) ->
				total = 0
				for i in [0...18]
					if i % 5 != 4
						total = (total + parseInt orcid[i]) * 2
				remainder = total % 11
				result = (12 - remainder) % 11
				if result == 10 then result = "X" else result = result.toString()
				result == orcid[18]

			is_valid_orcid = (orcid) ->
				regexp = /^(?:(?:http:\/\/)?orcid\.org\/)?(\d{4}\-\d{4}\-\d{4}\-\d\d\d[\dx])$/i
				result = regexp.exec orcid
				return false if not result
				is_valid_checksum result[1]

			ctrl.$validators.email = (modelValue, viewValue) ->
				return true if is_valid_orcid viewValue
				email_validator modelValue, viewValue if email_validator

	App.controller "ShareProjectModalController", ["$scope", "$modalInstance", "$timeout", "projectMembers", "$modal", "$http", ($scope, $modalInstance, $timeout, projectMembers, $modal, $http) ->
		$scope.inputs = {
			privileges: "readAndWrite"
			contacts: []
		}
		$scope.state = {
			error: null
			inflight: false
			startedFreeTrial: false
		}

		$modalInstance.opened.then () ->
			$timeout () ->
				$scope.$broadcast "open"
			, 200

		INFINITE_COLLABORATORS = -1
		$scope.$watch "project.members.length", (noOfMembers) ->
			allowedNoOfMembers = $scope.project.features.collaborators
			$scope.canAddCollaborators = noOfMembers < allowedNoOfMembers or allowedNoOfMembers == INFINITE_COLLABORATORS

		$scope.addMember = () ->
			return if $scope.inputs.contact.length == 0
			request = projectMembers.addMember $scope.inputs.contact, $scope.inputs.privileges

			request
				.success (data) ->
					if data.users?
						users = data.users
					else if data.user?
						users = [data.user]
					else
						users = []

					$scope.project.members.push users...
				.error () ->
					$scope.state.inflight = false
					$scope.state.error = true

		$scope.removeMember = (member) ->
			$scope.state.error = null
			$scope.state.inflight = true
			projectMembers
				.removeMember(member)
				.success () ->
					$scope.state.inflight = false
					index = $scope.project.members.indexOf(member)
					return if index == -1
					$scope.project.members.splice(index, 1)
				.error () ->
					$scope.state.inflight = false
					$scope.state.error = "Sorry, something went wrong :("

		$scope.openMakePublicModal = () ->
			$modal.open {
				templateUrl: "makePublicModalTemplate"
				controller:  "MakePublicModalController"
				scope: $scope
			}

		$scope.openMakePrivateModal = () ->
			$modal.open {
				templateUrl: "makePrivateModalTemplate"
				controller:  "MakePrivateModalController"
				scope: $scope
			}

		$scope.done = () ->
			$modalInstance.close()

		$scope.cancel = () ->
			$modalInstance.dismiss()
	]

	App.controller "MakePublicModalController", ["$scope", "$modalInstance", "settings", ($scope, $modalInstance, settings) ->
		$scope.inputs = {
			privileges: "readAndWrite"
		}

		$scope.makePublic = () ->
			$scope.project.publicAccesLevel = $scope.inputs.privileges
			settings.saveProjectAdminSettings({publicAccessLevel: $scope.inputs.privileges})
			$modalInstance.close()

		$scope.cancel = () ->
			$modalInstance.dismiss()
	]

	App.controller "MakePrivateModalController", ["$scope", "$modalInstance", "settings", ($scope, $modalInstance, settings) ->
		$scope.makePrivate = () ->
			$scope.project.publicAccesLevel = "private"
			settings.saveProjectAdminSettings({publicAccessLevel: "private"})
			$modalInstance.close()

		$scope.cancel = () ->
			$modalInstance.dismiss()
	]