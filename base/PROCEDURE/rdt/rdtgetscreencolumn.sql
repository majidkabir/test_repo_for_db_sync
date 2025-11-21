SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtGetScreenColumn                                 */
/* Creation Date:                                                       */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Calling from RDT Trace Application datawindow               */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7                                                           */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */ 
/************************************************************************/
CREATE PROC [RDT].[rdtGetScreenColumn] 
   @cInMessage NVARCHAR(MAX) 
AS 
DECLARE @iDoc        INT
       ,@cColName    NVARCHAR(20)
       ,@cColValue   NVARCHAR(60)
       ,@cSQL        NVARCHAR(4000)
       ,@cMobile     NVARCHAR(10)  
  
DECLARE @XML_Result  TABLE 
        (
            Mobile NVARCHAR(10)
           ,Typ NVARCHAR(20)
           ,xPos NVARCHAR(10)
           ,yPos NVARCHAR(10)
           ,LabelValue NVARCHAR(60)
           ,FieldLength NVARCHAR(10)
           ,ColName NVARCHAR(20)
        )  

-- Get a  handle for the XML doc  
EXEC sp_xml_preparedocument @iDoc OUTPUT
    ,@cInMessage  

SELECT TOP 1 @cMobile = [number]
FROM   OPENXML(@iDoc ,'/tordt' ,1) WITH ([number] NVARCHAR(10) '@number')


INSERT INTO @XML_Result
SELECT @cMobile
      ,[Typ]
      ,[X]
      ,[Y]
      ,CASE WHEN [Typ] = 'input' 
            THEN ISNULL([Default] ,'')  
            ELSE ISNULL([VALUE] ,'') 
       END AS [Value]
      ,CASE WHEN ISNULL([Length] ,'')  ='NULL' THEN ''
            WHEN CAST(ISNULL([Length] ,'0') AS INT) > 30 THEN '20' 
            ELSE ISNULL([Length] ,'') 
       END AS [Length]
      ,CASE WHEN ISNULL([ID] ,'')  ='NULL' THEN '' ELSE ISNULL([ID] ,'') END AS ColName
FROM   OPENXML(@iDoc ,'/tordt/field' ,2) WITH 
       (
           [Typ] NVARCHAR(20) '@typ'
          ,[x] NVARCHAR(60) '@x'
          ,[y] NVARCHAR(60) '@y'
          ,[value] NVARCHAR(60) '@value'
          ,[length] NVARCHAR(10) '@length'
          ,[id] NVARCHAR(20) '@id'
          ,[default] NVARCHAR(60) '@default'
       )  
   

-- Release the handle  
EXEC sp_xml_removedocument @iDoc  

SELECT *
FROM   @XML_Result


GO