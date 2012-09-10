
window.probo =

  initialize: (config) ->
    @preloadedModules = {}

    if window.jasmine?
      @initializeJasmine(config)

    require config.preloadModules, (modules...) =>
      for modulePath, moduleIndex in config.preloadModules
        @preloadedModules[modulePath] = modules[moduleIndex]
      config.ready?()

  setupTest: (configFunc) ->

    factoryName = "Factory" + Math.floor(Math.random() * 100000000)
    contextFactory = (callback) =>

      config = configFunc()

      # create a new map which will override the path to a given dependencies
      # so if we have a module in m1, requiresjs will look now unter   
      # stub_m1
      map = {}

      for key, value of config.stubs
        stubname = 'stub_' + key
        map[key] = stubname

      # Map and defined preloaded modules for load only once and use forever behavior
      for preloadedModulePath, preloadedModule of @preloadedModules
        preloadedModuleName = 'preloaded_' + preloadedModulePath
        map[preloadedModulePath] = preloadedModuleName
        define preloadedModuleName, -> preloadedModule

      # create a new requireContext with the new dependency paths
      requireContext = require.config
        context: requireContextName = Math.floor(Math.random() * 100000000)
        baseUrl: require2.baseUrl
        shim: require2.shim
        paths: require2.paths
        map:
          "*": map

      # safe all stubs for easy lookup
      stubs = {}
      
      # create new definitions that will return our passed stubs or mocks
      for key, value of config.stubs
        stubname = 'stub_' + key
        do (value) ->
          define stubname, ->
            value
          stubs[key] = value

      # generate a context for the test
      testContext =
        stubs: stubs
        require: requireContext
        isDone: no
        requireContextName: requireContextName


      subjectModules = []
      subjectNames = []
      for subjectName,subjectModule of config.subject
        subjectNames.push subjectName
        subjectModules.push subjectModule

      requireContext subjectModules, (subjectObjects...) ->
        subjects = {}
        for subjectObject, subjectIndex in subjectObjects
          subjects[subjectNames[subjectIndex]] = subjectObject
        callback(subjects, testContext)
        testContext.isDone = yes

      testContext

    contextFactory.factoryName = factoryName
    contextFactory

  setupJasmineTest: (config) ->
    {currentSuite} = jasmine.getEnv()
    currentSuite.testFactory = probo.setupTest config

    beforeEach ->    

      runs ->
        @context = currentSuite.testFactory (subjects, tc) => 
          @subjects = subjects
          for subjectName, subject of subjects
            @[subjectName] ?= subject
        {@stubs} = @context

      waitsFor (-> 
        @context?.isDone ? false
      ), "Loading of requirejs dependencies took to long", 100

  initializeJasmine: (config) ->
    jasmine.WaitsForBlock.TIMEOUT_INCREMENT = 1;

    if config.profile ? no

      if config.profile is yes or config.profile is 'time'
        beforeEach ->
          console.time @description
        afterEach ->
          console.timeEnd @description
      if config.profile is yes
        beforeEach ->
          console.profile @description if config.profile is yes
        afterEach ->
          console.profileEnd @description

    if config.tests?
      config.ready = ->
        require ['tests/All'], ->
          jasmineEnv = jasmine.getEnv()
          jasmineEnv.updateInterval = 1000

          htmlReporter = new jasmine.HtmlReporter()

          jasmineEnv.addReporter(htmlReporter)

          jasmineEnv.specFilter = (spec) ->
            htmlReporter.specFilter(spec)

          currentWindowOnload = window.onload

          window.onload = ->
            if currentWindowOnload
              currentWindowOnload()
            jasmineEnv.execute()

    window.setup = (config) ->
      probo.setupJasmineTest config    

