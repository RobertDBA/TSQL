 ;WITH CTE
          AS (SELECT  
				 ROW_NUMBER() OVER (ORDER BY  xed.value('@timestamp', 'datetime')) AS  DeadlockID ,
				xed.value('@timestamp', 'datetime') AS Creation_Date ,
                xed.query('.') AS DeadlockGraph 
       
        FROM    ( SELECT    
							CAST([target_data] AS XML) AS Target_Data
                  FROM      sys.dm_xe_session_targets AS xt
                            INNER JOIN sys.dm_xe_sessions AS xs ON xs.address = xt.event_session_address
                  WHERE     xs.name = N'system_health'
                            AND xt.target_name = N'ring_buffer'
                ) AS XML_Data
                CROSS APPLY Target_Data.nodes('RingBufferTarget/event[@name="xml_deadlock_report"]')
                AS XEventData ( xed )
             )
			,[Process]
          AS ( SELECT   
						 DeadlockID,
						 eventlist.list.value('@timestamp','date') AS EventDate,
						 eventlist.list.value('@timestamp','datetime') AS EventDateTime,
						 eventlist.list.value('@timestamp','time') AS EventTime,
						 eventlist.list.value('@name','sysname') AS Name,
						 eventlist.list.value('@package','sysname') AS Package,
						 victims.list.value('@id', 'varchar(50)') AS VictimProcess,
						 processlist.process.value('@id', 'varchar(100)') AS ProcessID ,
						 processlist.process.value ('@taskpriority', 'int') AS [TaskPriority],
						 processlist.process.value ('@logused', 'bigint') AS [LogUsed],
						 processlist.process.value ('@waitresource', 'sysname') AS [WaitResource],
						 processlist.process.value ('@waittime', 'bigint') AS [WaitTime],
						 processlist.process.value ('@ownerId', 'bigint') AS [OwnerID],
						 processlist.process.value ('@transactionname', 'sysname') AS TransactionName,
						 processlist.process.value ('@lasttranstarted', 'datetime') AS LastTranStarted,
						 processlist.process.value ('@lockMode', 'varchar(10)') AS Lockmode,
						 processlist.process.value ('@schedulerid', 'tinyint') AS SchedulerID,
						 processlist.process.value ('@kpid', 'int') AS kpid,
						 processlist.process.value ('@status', 'sysname') AS [status],
						 processlist.process.value ('@spid', 'int') AS spid,
						 processlist.process.value ('@sbid', 'int') AS sbid,
						 processlist.process.value ('@ecid', 'int') AS ecid,
						 processlist.process.value ('@priority', 'int') AS [Priority],
						 processlist.process.value ('@trancount', 'tinyint') AS [TranCount],
						 processlist.process.value ('@lastbatchstarted', 'datetime') AS LastBatchStarted,
						 processlist.process.value ('@lastbatchcompleted', 'datetime') AS LastBatchCompleted,
						 processlist.process.value ('@lastattention', 'datetime') AS LastAttention,
						 processlist.process.value ('@clientapp', 'sysname') AS ClientApp,
						 processlist.process.value ('@hostname', 'sysname') AS HostName,
						 processlist.process.value ('@hostpid', 'int') AS Hostpid,
						 processlist.process.value ('@loginname', 'sysname') AS LoginName,
						 processlist.process.value ('@isolationlevel', 'sysname') AS IsolationLevel,
						 processlist.process.value ('@xactid', 'bigint') AS xactid,
						 processlist.process.value ('@currentdb', 'int') AS currentdb,
						 DB_NAME(processlist.process.value ('@currentdb', 'int')) AS currentDatabaseName,
						 processlist.process.value ('@lockTimeout', 'bigint') AS lockTimeout,
						 processlist.process.value ('@clientoption1', 'bigint') AS clientoption1,
						 processlist.process.value ('@clientoption2', 'bigint') AS clientoption2,
						 frameList.frame.value('@procname', 'sysname') AS procname,
						 frameList.frame.value('@line', 'smallint') AS line,
						 frameList.frame.value('@stmtstart', 'int') AS stmtstart,
						 frameList.frame.value('@stmtend', 'int') AS  stmtend,
						 CONVERT(VARBINARY(64),frameList.frame.value('@sqlhandle', 'varchar(max)'),1) AS  sqlhandle,
						 frameList.frame.value('(.)','varchar(max)') AS [Deadlock_Sqlstatement],
						 inputbufList.Input.value('(.)','varchar(max)') AS [inputbuf],
						 cte.DeadlockGraph
						 FROM     CTE
						 OUTER APPLY CTE.DeadlockGraph.nodes('//event')
                        AS eventlist ( list )
						OUTER APPLY CTE.DeadlockGraph.nodes('//deadlock/victim-list/victimProcess')
                        AS victims ( list )
						OUTER APPLY CTE.DeadlockGraph.nodes('//deadlock/process-list')
                        AS processroot ( list )
                        OUTER APPLY processroot.list.nodes('*') AS processlist ( process )
                        OUTER APPLY processlist.process.nodes('executionStack/frame[1]')
                        AS frameList ( frame )
						OUTER APPLY processlist.process.nodes('inputbuf')
                        AS inputbufList ( input )
						)
						 ,[Resource]
          AS ( SELECT   
						DeadlockID,
						resourcelist.keylock.value('@hobtid', 'bigint') AS hobtid ,
						resourcelist.keylock.value('@dbid', 'tinyint') AS [dbid],
						resourcelist.keylock.value('@objectname', 'sysname') AS ObjectName ,
						resourcelist.keylock.value ('@indexname', 'sysname') AS 	indexname,
						resourcelist.keylock.value('@id', 'varchar(100)') AS ID ,
						resourcelist.keylock.value('@mode', 'varchar(10)') AS mode,
						resourcelist.keylock.value('@associatedObjectId', 'bigint') AS AssociatedObjectId,
                        OwnerList.Owner.value('@id', 'varchar(200)') AS ProcessId ,
                        REPLACE(resourcelist.keylock.value('local-name(.)','varchar(100)'), 'lock','') AS LockEvent,
                        resourcelist.keylock.value('@WaitType', 'varchar(100)') AS WaitType ,
                        WaiterList.waiter.value('@id', 'varchar(200)') AS WaitProcessId ,
						OwnerList.Owner.value('@mode', 'varchar(10)') AS LockMode ,
                        WaiterList.waiter.value('@mode', 'varchar(10)') AS WaitMode,
						WaiterList.waiter.value('@requestType', 'varchar(20)') AS requestType
               FROM     CTE
						CROSS APPLY CTE.DeadlockGraph.nodes('//deadlock/resource-list')
                        AS Lock ( list )
                        CROSS APPLY Lock.list.nodes('*') AS resourcelist ( keylock )
                        OUTER APPLY resourcelist.keylock.nodes('owner-list/owner')
                        AS OwnerList ( Owner )
                        CROSS APPLY resourcelist.keylock.nodes('waiter-list/waiter')
                        AS WaiterList (waiter )
						)
		SELECT
		ROW_NUMBER() OVER (ORDER BY r.DeadlockID) AS [RowNumber],
		r.DeadlockID ,
		DENSE_RANK() OVER (PARTITION BY  r.DeadlockID   ORDER BY p.processid) AS StatementID,
		p.EventDate,
		p.EventDateTime,
		p.EventTime,
		P.Name,
		p.Package,
		 p.* FROM [process] p 
		left JOIN [Resource] r
		ON p.processid = r.processid
		AND p.DeadlockID = r.DeadlockID
		GO