USE master
GO


--Disable BPE
ALTER SERVER CONFIGURATION 
    SET BUFFER POOL EXTENSION OFF;
GO

--Enable BPE 
ALTER SERVER CONFIGURATION   
SET BUFFER POOL EXTENSION ON  
    (FILENAME = 'D:\SSDCACHE\MSSQLSERVER.BPE', SIZE = 12 GB);