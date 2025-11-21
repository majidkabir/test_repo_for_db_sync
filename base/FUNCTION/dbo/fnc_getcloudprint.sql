SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: fnc_GetCloudPrint                                           */
/* Creation Date: 2023-10-23                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: Get Print Over internet Method                              */
/*        :                                                             */
/*                                                                      */
/* Called By:                                                           */
/*          :                                                           */
/*          :                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2023-10-23  Wan      1.0   Created & DevOps Conbine Script           */
/************************************************************************/
CREATE   FUNCTION [dbo].[fnc_GetCloudPrint] 
( 
   @c_ModuleID       NVARCHAR(10)
,  @c_PrintType      NVARCHAR(10)
,  @c_PrinterID      NVARCHAR(100)
)
RETURNS INT
AS
BEGIN
  
   DECLARE @n_PrintOverInternet  INT = 1

   -- Search by ModuleID
   IF @c_ModuleID <> ''
   BEGIN
      SET @n_PrintOverInternet = 0
      SELECT @n_PrintOverInternet = IIF(c.UDF01 = 'PrintBYCPC',1,0)  
      FROM dbo.CODELKUP AS c (NOLOCK)
      WHERE c.listName = 'WMRptModID'
      AND c.Code = @c_ModuleID
   END 

   IF @n_PrintOverInternet = 1 AND @c_PrintType <> ''
   BEGIN
      SET @n_PrintOverInternet = 0
      SELECT @n_PrintOverInternet = IIF(c.UDF01 = 'PrintBYCPC',1,0)  
      FROM dbo.CODELKUP AS c (NOLOCK)
      WHERE c.listName = 'WMPrintTyp'
      AND c.Code = @c_PrintType
   END  
   
   IF @n_PrintOverInternet = 1 AND @c_PrinterID <> ''
   BEGIN
      -- Search BY PrinterID
      SET @n_PrintOverInternet = 0
      SELECT @n_PrintOverInternet = IIF(cpc.PrintClientID IS NULL,0,1)               
      FROM rdt.RDTPrinter AS rp (NOLOCK) 
      LEFT OUTER JOIN dbo.CloudPrintConfig AS cpc WITH (NOLOCK) ON cpc.PrintClientID = rp.CloudPrintClientID 
      WHERE rp.PrinterID = @c_PrinterID
   END   
   
   RETURN @n_PrintOverInternet
END 

GO