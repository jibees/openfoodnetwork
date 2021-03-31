angular.module("admin.orders").controller "ordersCtrl", ($scope, $timeout, RequestMonitor, Orders, SortOptions, $window, $filter, $location) ->
  $scope.RequestMonitor = RequestMonitor
  $scope.pagination = Orders.pagination
  $scope.orders = Orders.all
  $scope.sortOptions = SortOptions
  $scope.per_page_options = [
    {id: 15, name: t('js.admin.orders.index.per_page', results: 15)},
    {id: 50, name: t('js.admin.orders.index.per_page', results: 50)},
    {id: 100, name: t('js.admin.orders.index.per_page', results: 100)}
  ]
  $scope.selected_orders = []
  $scope.checkboxes = {}
  $scope.selected = false
  $scope.select_all = false
  $scope.poll = 0
  $scope.rowStatus = {}

  $scope.initialise = ->
    params = $location.search()
    # Get all params from url (if presents) and then put into $scope
    $scope.per_page = parseInt(params.per_page) || 15
    if (params.shipping_method_id)
      $scope.shipping_method_id = parseInt(params.shipping_method_id)
    
    # All params specified in the query 'q'
    $scope.q = {}
    searchKeys =  ["completed_at_gteq",
     "completed_at_lteq",
     "state_eq",
     "number_cont",
     "email_cont"
     "bill_address_firstname_start",
     "bill_address_lastname_start"
     ]
    for key in searchKeys when params["q["+key+"]"]
      $scope.q[key] = params["q["+key+"]"]

    # Special for arrays 'distributor_id_in' and 'order_cycle_id_in'. Arrays of arrays: q[params][]
    for key in ["distributor_id_in", "order_cycle_id_in"] when params["q["+key+"][]"]
      $scope.q[key] = params["q["+key+"][]"]
    
    # Special case for 'completed_at_not_null', with 'true' as default value
    $scope.q.completed_at_not_null = if params["q[completed_at_not_null]"] then params["q[completed_at_not_null]"] else true
    
    # Special case for sorting param and its default value "completed_at desc"
    $scope.sorting = if params["q[s]"] then params["q[s]"] else "completed_at desc"
    
    $scope.fetchResults(parseInt(params.page) || null)

  $scope.writeParamsToUrl = (params) ->
    for k,v of params
      $location.search(k, v)
    

  $scope.fetchResults = (page=1) ->
    startDateWithTime = $scope.appendStringIfNotEmpty($scope['q']['completed_at_gteq'], ' 00:00:00')
    endDateWithTime = $scope.appendStringIfNotEmpty($scope['q']['completed_at_lteq'], ' 23:59:59')

    $scope.resetSelected()
    params = {
      'q[completed_at_gteq]': startDateWithTime,
      'q[completed_at_lteq]': endDateWithTime,
      'q[state_eq]': $scope['q']['state_eq'],
      'q[number_cont]': $scope['q']['number_cont'],
      'q[email_cont]': $scope['q']['email_cont'],
      'q[bill_address_firstname_start]': $scope['q']['bill_address_firstname_start'],
      'q[bill_address_lastname_start]': $scope['q']['bill_address_lastname_start'],
      # Set default checkbox values to null. See: https://github.com/openfoodfoundation/openfoodnetwork/pull/3076#issuecomment-440010498
      'q[completed_at_not_null]': $scope['q']['completed_at_not_null'] || null,
      'q[distributor_id_in][]': $scope['q']['distributor_id_in'],
      'q[order_cycle_id_in][]': $scope['q']['order_cycle_id_in'],
      'q[s]': $scope.sorting || 'completed_at desc',
      shipping_method_id: $scope.shipping_method_id,
      per_page: $scope.per_page,
      page: page
    }
    $scope.writeParamsToUrl(params)
    RequestMonitor.load(Orders.index(params).$promise)

  $scope.appendStringIfNotEmpty = (baseString, stringToAppend) ->
    return baseString unless baseString

    baseString + stringToAppend

  $scope.resetSelected = ->
    $scope.selected_orders.length = 0
    $scope.selected = false
    $scope.select_all = false
    $scope.checkboxes = {}

  $scope.toggleSelection = (id) ->
    index = $scope.selected_orders.indexOf(id)

    if index == -1
      $scope.selected_orders.push(id)
    else
      $scope.selected_orders.splice(index, 1)

  $scope.toggleAll = ->
    $scope.selected_orders.length = 0
    $scope.orders.forEach (order) ->
      $scope.checkboxes[order.id] = $scope.select_all
      $scope.selected_orders.push order.id if $scope.select_all

  $scope.$watch 'sortOptions', (sort) ->
    return unless sort && sort.predicate != ""

    $scope.sorting = sort.getSortingExpr()
    $scope.fetchResults()
  , true

  $scope.capturePayment = (order) ->
    $scope.rowAction('capture', order)

  $scope.shipOrder = (order) ->
    $scope.rowAction('ship', order)

  $scope.rowAction = (action, order) ->
    $scope.rowStatus[order.id] = "loading"

    Orders[action](order).$promise.then (data) ->
      $scope.rowStatus[order.id] = "success"
      $timeout(->
        $scope.rowStatus[order.id] = null
      , 1500)
    , (error) ->
      $scope.rowStatus[order.id] = "error"

  $scope.changePage = (newPage) ->
    $scope.page = newPage
    $scope.fetchResults(newPage)
