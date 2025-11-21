SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_CaptureUnauthorizeAccess                       */
/* Creation Date: 04-Jun-2002                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 25-Oct-2012            1.0 Initial Version                           */
/* 07-Nov-2016  Ting      1.1 Review the program name                   */
/* 10-Nov-2020  Shong     1.2 Include Duration when insert into         */
/*                            wms_sysprocess                            */
/* 11-Nov-2020  Ting      1.3 remove wms_sysprocess logging             */
/************************************************************************/
CREATE PROC [dbo].[isp_CaptureUnauthorizeAccess] @s_DBName nvarchar(20)
AS
   SET NOCOUNT ON

   IF DATEPART(HOUR, GETDATE()) = 3  -- only run this during off peak (3am)        
      DELETE UnauthorizeAccess
      WHERE DATEDIFF(DAY, AddDate, GETDATE()) > 7

   INSERT INTO [UnauthorizeAccess] ([AddDate]
   , [SPID]
   , [ProgramName]
   , [HostName]
   , [Login_Time]
   , [Login_ID]
   , [Net_Address])
      SELECT DISTINCT
         GETDATE() AS AddDate,
         sp.spid,
         sp.program_name,
         sp.hostname,
         sp.Login_Time,
         sp.loginame,
         SUBSTRING(sp.net_address, 1, 2) + '-' +
         SUBSTRING(sp.net_address, 3, 2) + '-' +
         SUBSTRING(sp.net_address, 5, 2) + '-' +
         SUBSTRING(sp.net_address, 7, 2) + '-' +
         SUBSTRING(sp.net_address, 9, 2) + '-' +
         SUBSTRING(sp.net_address, 11, 2)
      FROM master..sysprocesses sp WITH (NOLOCK)
      JOIN master..sysdatabases sd WITH (NOLOCK)
         ON sp.dbid = sd.dbid
      WHERE sd.name = @s_DBName
      AND sp.program_name NOT IN (
      'Microsoft SQL Server',
      'EXceed WMS',
      'dxscheduler',
      'DTS Designer',
      'Microsoft (r) Windows Script Host',
      'jTDS',
      'MS SQLEM',
      'Brio Enterprise Client',
      'NIKE Pick&Pack',
      'EXceed',
      'EXceed 6.0',      --KH01        
      'Exceed 7.0',
      'Zeus',
      'DTS Designer',
      '.Net SqlClient Data Provider',
      'GenericWebServiceHost',
      'EXCEL2WMS',
      'LFLigthLink',
      'PowerBuilder',
      'RDT',
      'RDT Print Server',
      'RDT_Print',
      'RDTTrace',
      'SQL Server Log Shipping',
      'WMS_DPC_Listener',
      'WMS PDA',
      'Microsoft? Query',
      'GenericTCPSocketListener_WCS', 'QCSvc', 'Microsoft JDBC Driver for SQL Server', 'IgniteMonitor',
      'RDT_PrintZPL', 'FTSP', 'LEAF_OMS', 'Managed Backup'

      )
      AND sp.program_name NOT LIKE 'SQLAgent %'
      AND sp.program_name NOT LIKE 'SQL Query Analyzer%'
      AND sp.program_name NOT LIKE 'SQL Server Profiler%'
      AND sp.program_name NOT LIKE 'Microsoft SQL Server Management Studio%'
      AND sp.program_name NOT LIKE 'QCmd_WS_Out_%'
      AND sp.program_name NOT LIKE '%QCSvc_%'
      AND sp.program_name NOT LIKE '%DTBSvc_%'
      AND sp.program_name NOT LIKE 'Red Gate Software%'
      AND sp.program_name NOT LIKE '%QueueCommander_WMS.exe%'
      AND sp.program_name NOT LIKE 'Inter Machine Link%'
      AND (sp.loginame = 'sa'
      AND sp.program_name <> '')
      AND (sp.loginame NOT IN ('QCmdUser', 'DataTransferBridgeUser', 'hyperionuser', 'ePODUser', 'FileExporter', 'AppDyn', 'LFMobile_Admin'))


GO