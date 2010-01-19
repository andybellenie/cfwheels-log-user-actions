<cfcomponent displayname="Log User Actions" output="false" mixin="model">

	<cffunction name="init">
		<cfset this.version = "0.9,1.0">
		<cfreturn this>
	</cffunction>

	<cffunction name="$initModelClass" returntype="any" access="public" output="false">
		<cfargument name="name" type="string" required="true">
		<cfscript>
			var loc = {};
			variables.wheels = {};
			variables.wheels.errors = [];
			variables.wheels.class = {};
			variables.wheels.class.name = arguments.name;
			variables.wheels.class.RESQLOperators = "((?: LIKE)|(?:<>)|(?:<=)|(?:>=)|(?:!=)|(?:!<)|(?:!>)|=|<|>)";
			variables.wheels.class.RESQLWhere = "(#variables.wheels.class.RESQLOperators# ?)(''|'.+?'()|(-?[0-9]|\.)+()|\(-?[0-9]+(,-?[0-9]+)*\))(($|\)| (AND|OR)))";  
			variables.wheels.class.mapping = {};
			variables.wheels.class.properties = {};
			variables.wheels.class.calculatedProperties = {};
			variables.wheels.class.associations = {};
			variables.wheels.class.callbacks = {};
			variables.wheels.class.connection = {datasource=application.wheels.dataSourceName, username=application.wheels.dataSourceUserName, password=application.wheels.dataSourcePassword};
			loc.callbacks = "afterNew,afterFind,afterInitialization,beforeDelete,afterDelete,beforeSave,afterSave,beforeCreate,afterCreate,beforeUpdate,afterUpdate,beforeValidation,afterValidation,beforeValidationOnCreate,afterValidationOnCreate,beforeValidationOnUpdate,afterValidationOnUpdate";
			loc.iEnd = ListLen(loc.callbacks);
			for (loc.i=1; loc.i <= loc.iEnd; loc.i++)
				variables.wheels.class.callbacks[ListGetAt(loc.callbacks, loc.i)] = ArrayNew(1);
			loc.validations = "onSave,onCreate,onUpdate";
			loc.iEnd = ListLen(loc.validations);
			for (loc.i=1; loc.i <= loc.iEnd; loc.i++)
				variables.wheels.class.validations[ListGetAt(loc.validations, loc.i)] = ArrayNew(1);
			
			// run developer's init method if it exists
			if (StructKeyExists(variables, "init"))
				init();
	
			// load the database adapter
			variables.wheels.class.adapter = $assignAdapter();
	
			// set the table name unless set manually by the developer
			if (!StructKeyExists(variables.wheels.class, "tableName"))
			{
				variables.wheels.class.tableName = LCase(pluralize(variables.wheels.class.name));
				if (Len(application.wheels.tableNamePrefix))
					variables.wheels.class.tableName = application.wheels.tableNamePrefix & "_" & variables.wheels.class.tableName;
			}
	
			// introspect the database
			try
			{
				loc.columns = $dbinfo(datasource=variables.wheels.class.connection.datasource, username=variables.wheels.class.connection.username, password=variables.wheels.class.connection.password, type="columns", table=variables.wheels.class.tableName);
			}
			catch(Any e)
			{
				$throw(type="Wheels.TableNotFound", message="The '#variables.wheels.class.tableName#' table could not be found in the database.", extendedInfo="Add a table named '#variables.wheels.class.tableName#' to your database or if you already have a table you want to use for this model you can tell Wheels to use it with the 'table' method.");
			}
			variables.wheels.class.keys = "";
			variables.wheels.class.propertyList = "";
			variables.wheels.class.columnList = "";
			loc.iEnd = loc.columns.recordCount;
			for (loc.i=1; loc.i <= loc.iEnd; loc.i++)
			{
				// set up properties and column mapping
				loc.property = loc.columns["column_name"][loc.i]; // default the column to map to a property with the same name 
				for (loc.key in variables.wheels.class.mapping)
				{
					if (variables.wheels.class.mapping[loc.key].type == "column" && variables.wheels.class.mapping[loc.key].value == loc.property)
					{
						// developer has chosen to map this column to a property with a different name so set that here
						loc.property = loc.key;
						break;
					}
				}
				loc.type = SpanExcluding(loc.columns["type_name"][loc.i], "( ");
				variables.wheels.class.properties[loc.property] = {};
				variables.wheels.class.properties[loc.property].type = variables.wheels.class.adapter.$getType(loc.type);
				variables.wheels.class.properties[loc.property].column = loc.columns["column_name"][loc.i];
				variables.wheels.class.properties[loc.property].scale = loc.columns["decimal_digits"][loc.i];
				loc.defaultValue = loc.columns["column_default_value"][loc.i];
				if ((Left(loc.defaultValue,2) == "((" && Right(loc.defaultValue,2) == "))") || (Left(loc.defaultValue,2) == "('" && Right(loc.defaultValue,2) == "')"))
					loc.defaultValue = Mid(loc.defaultValue, 3, Len(loc.defaultValue)-4);
				variables.wheels.class.properties[loc.property].defaultValue = loc.defaultValue;
				if (loc.columns["is_primarykey"][loc.i])
				{
					variables.wheels.class.keys = ListAppend(variables.wheels.class.keys, loc.property);
				}
				variables.wheels.class.propertyList = ListAppend(variables.wheels.class.propertyList, loc.property);
				variables.wheels.class.columnList = ListAppend(variables.wheels.class.columnList, variables.wheels.class.properties[loc.property].column);
			}
			if (!Len(variables.wheels.class.keys))
				$throw(type="Wheels.NoPrimaryKey", message="No primary key exists on the '#variables.wheels.class.tableName#' table.", extendedInfo="Set an appropriate primary key (or multiple keys) on the '#variables.wheels.class.tableName#' table.");
	
			// add calculated properties
			variables.wheels.class.calculatedPropertyList = "";
			for (loc.key in variables.wheels.class.mapping)
			{
				if (variables.wheels.class.mapping[loc.key].type != "column")
				{
					variables.wheels.class.calculatedPropertyList = ListAppend(variables.wheels.class.calculatedPropertyList, loc.key);
					variables.wheels.class.calculatedProperties[loc.key] = {};
					variables.wheels.class.calculatedProperties[loc.key][variables.wheels.class.mapping[loc.key].type] = variables.wheels.class.mapping[loc.key].value;
				}
			}
	
			// set up soft deletion and time stamping if the necessary columns in the table exist
			if (Len(application.wheels.softDeleteProperty) && StructKeyExists(variables.wheels.class.properties, application.wheels.softDeleteProperty))
			{
				variables.wheels.class.softDeletion = true;
				variables.wheels.class.softDeleteColumn = variables.wheels.class.properties[application.wheels.softDeleteProperty].column;
			}
			else
			{
				variables.wheels.class.softDeletion = false;
			}
	
			if (Len(application.wheels.timeStampOnCreateProperty) && StructKeyExists(variables.wheels.class.properties, application.wheels.timeStampOnCreateProperty))
			{
				variables.wheels.class.timeStampingOnCreate = true;
				variables.wheels.class.timeStampOnCreateProperty = application.wheels.timeStampOnCreateProperty;
			}
			else
			{
				variables.wheels.class.timeStampingOnCreate = false;
			}
	
			if (Len(application.wheels.timeStampOnUpdateProperty) && StructKeyExists(variables.wheels.class.properties, application.wheels.timeStampOnUpdateProperty))
			{
				variables.wheels.class.timeStampingOnUpdate = true;
				variables.wheels.class.timeStampOnUpdateProperty = application.wheels.timeStampOnUpdateProperty;
			}
			else
			{
				variables.wheels.class.timeStampingOnUpdate = false;
			}
			
			// additional code for LogUserActions plugin
			variables.wheels.class.logUserOnCreate = false;
			variables.wheels.class.logUserOnUpdate = false;
			variables.wheels.class.logUserOnDelete = false;
			variables.wheels.class.userIdLocation = "session.userId";
			
			// set different cfsqltype for the user id field if specified in the application config
			if (StructKeyExists(application.wheels,"userIdLocation") && Len(application.wheels.userIdLocation))
			{
				variables.wheels.class.userIdLocation = application.wheels.userIdLocation;
			}
	
			if (StructKeyExists(application.wheels,"logUserOnCreateProperty") && StructKeyExists(variables.wheels.class.properties, application.wheels.logUserOnCreateProperty)) 
			{
				variables.wheels.class.logUserOnCreate = true;
				variables.wheels.class.logUserOnCreateProperty = application.wheels.logUserOnCreateProperty;
			}
	
			if (StructKeyExists(application.wheels,"logUserOnUpdateProperty") && StructKeyExists(variables.wheels.class.properties, application.wheels.logUserOnUpdateProperty)) 
			{
				variables.wheels.class.logUserOnUpdate = true;
				variables.wheels.class.logUserOnUpdateProperty = application.wheels.logUserOnUpdateProperty;
			}
	
			if (StructKeyExists(application.wheels,"logUserOnDeleteProperty") && StructKeyExists(variables.wheels.class.properties, application.wheels.logUserOnDeleteProperty)) 
			{
				variables.wheels.class.logUserOnDelete = true;
				variables.wheels.class.logUserOnDeleteProperty = application.wheels.logUserOnDeleteProperty;
			}	
			// end additional code for LogUserActions plugin
			
		</cfscript>
		<cfreturn this>
	</cffunction>

	<cffunction name="$create" returntype="boolean" access="public" output="false">
		<cfargument name="parameterize" type="any" required="true">
		<cfscript>
			var loc = {};
			if (variables.wheels.class.timeStampingOnCreate)
				this[variables.wheels.class.timeStampOnCreateProperty] = Now();
			
			// additional code for LogUserActions plugin
			if (variables.wheels.class.logUserOnCreate && IsDefined(variables.wheels.class.userIdLocation))
				this[variables.wheels.class.logUserOnCreateProperty] = Evaluate(variables.wheels.class.userIdLocation);
			// end additional code for LogUserActions plugin
	
			loc.sql = [];
			loc.sql2 = [];
			ArrayAppend(loc.sql, "INSERT INTO #variables.wheels.class.tableName# (");
			ArrayAppend(loc.sql2, " VALUES (");
			for (loc.key in variables.wheels.class.properties)
			{
				if (StructKeyExists(this, loc.key))
				{
					ArrayAppend(loc.sql, variables.wheels.class.properties[loc.key].column);
					ArrayAppend(loc.sql, ",");
					loc.param = {value=this[loc.key], type=variables.wheels.class.properties[loc.key].type, scale=variables.wheels.class.properties[loc.key].scale, null=this[loc.key] == ""};
					ArrayAppend(loc.sql2, loc.param);
					ArrayAppend(loc.sql2, ",");
				}
			}
			ArrayDeleteAt(loc.sql, ArrayLen(loc.sql));
			ArrayDeleteAt(loc.sql2, ArrayLen(loc.sql2));
			ArrayAppend(loc.sql, ")");
			ArrayAppend(loc.sql2, ")");
			loc.iEnd = ArrayLen(loc.sql);
			for (loc.i=1; loc.i <= loc.iEnd; loc.i++)
				ArrayAppend(loc.sql, loc.sql2[loc.i]);
			loc.ins = variables.wheels.class.adapter.$query(sql=loc.sql, parameterize=arguments.parameterize, $primaryKey=variables.wheels.class.keys);
			loc.generatedKey = variables.wheels.class.adapter.$generatedKey();
			if (StructKeyExists(loc.ins.result, loc.generatedKey))
				this[ListGetAt(variables.wheels.class.keys, 1)] = loc.ins.result[loc.generatedKey];
		</cfscript>
		<cfreturn true>
	</cffunction>
	
	<cffunction name="$update" returntype="boolean" access="public" output="false">
		<cfargument name="parameterize" type="any" required="true">
		<cfscript>
			var loc = {};
			if (variables.wheels.class.timeStampingOnUpdate)
				this[variables.wheels.class.timeStampOnUpdateProperty] = Now();
			
			// additional code for LogUserActions plugin
			if (variables.wheels.class.logUserOnUpdate && IsDefined(variables.wheels.class.userIdLocation))
				this[variables.wheels.class.logUserOnUpdateProperty] = Evaluate(variables.wheels.class.userIdLocation);
			// end additional code for LogUserActions plugin
	
			loc.sql = [];
			ArrayAppend(loc.sql, "UPDATE #variables.wheels.class.tableName# SET ");
			for (loc.key in variables.wheels.class.properties)
			{
				if (StructKeyExists(this, loc.key) && (!StructKeyExists(variables.$persistedProperties, loc.key) || Compare(this[loc.key], variables.$persistedProperties[loc.key])))
				{
					ArrayAppend(loc.sql, "#variables.wheels.class.properties[loc.key].column# = ");
					loc.param = {value=this[loc.key], type=variables.wheels.class.properties[loc.key].type, scale=variables.wheels.class.properties[loc.key].scale, null=this[loc.key] == ""};
					ArrayAppend(loc.sql, loc.param);
					ArrayAppend(loc.sql, ",");
				}
			}
			ArrayDeleteAt(loc.sql, ArrayLen(loc.sql));
			loc.sql = $addKeyWhereClause(sql=loc.sql);
			loc.upd = variables.wheels.class.adapter.$query(sql=loc.sql, parameterize=arguments.parameterize);
		</cfscript>
		<cfreturn true>
	</cffunction>

	<cffunction name="$addDeleteClause" returntype="array" access="public" output="false">
		<cfargument name="sql" type="array" required="true">
		<cfscript>
			var loc = {};
			if (variables.wheels.class.softDeletion)
			{
				ArrayAppend(arguments.sql, "UPDATE #variables.wheels.class.tableName# SET #variables.wheels.class.softDeleteColumn# = ");
				loc.deletedat = {value=Now(), type="cf_sql_timestamp"};
				ArrayAppend(arguments.sql, loc.deletedat);
	
				// additional code for LogUserActions plugin
				if (variables.wheels.class.logUserOnDelete && IsDefined(variables.wheels.class.userIdLocation))
				{
					ArrayAppend(arguments.sql, ", #variables.wheels.class.logUserOnDeleteProperty# = ");
					loc.deletedby.value = Evaluate(variables.wheels.class.userIdLocation);
					loc.deletedby.type = variables.wheels.class.properties[variables.wheels.class.logUserOnDeleteProperty].type;
					ArrayAppend(arguments.sql, loc.deletedby);
				}
				// end additional code for LogUserActions plugin
				
			}
			else
			{
				ArrayAppend(arguments.sql, "DELETE FROM #variables.wheels.class.tableName#");
			}
		</cfscript>
		<cfreturn arguments.sql>
	</cffunction>

</cfcomponent>