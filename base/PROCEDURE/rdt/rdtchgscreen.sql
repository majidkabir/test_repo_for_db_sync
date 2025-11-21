SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

 
/************************************************************************/  
/* Stored Procedure: rdtChgScreen                                       */  
/* Creation Date: 05-12-2004                                            */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Change the screen (by changing rdtXML_Elem)                 */  
/*                                                                      */  
/* Input Parameters: Mobile#                                            */  
/*                                                                      */  
/* Output Parameters: Error Number and Error Message                    */  
/*                                                                      */  
/* Return Status:                                                       */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/*                                                                      */  
/*                                                                      */  
/* Called By: rdtHandle                                                 */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Rev   Author    Purposes                                */  
/* 30-Oct-2008  1.1   Vicky     RDT 2.0 - Rewrite SP to avoid using     */  
/*                              Session table                           */ 
/* 25-Aug-2015  1.2   Shong     Performance Tuning                      */ 
/************************************************************************/  
CREATE PROC [RDT].[rdtChgScreen] (  
   @nMobile    INT  
)  
AS  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF  
  
  
   DECLARE @cTyp     NVARCHAR(125),  
           @cX       NVARCHAR(10),  
           @cY       NVARCHAR(10),  
           @cLength  NVARCHAR(10),  
           @cID      NVARCHAR(20),  
           @cDefault NVARCHAR(60),  
           @cType    NVARCHAR(20),  
           @cValue   NVARCHAR(125),  
           @cFocus   NVARCHAR(20),  
           @cNewID   NVARCHAR(20),  
           @cUpdFlag NVARCHAR(1),  
           @cColName NVARCHAR(20),  
           @cFldNum  NVARCHAR(2),  
           @cFieldAttr NVARCHAR(1), 
           @cFieldName NVARCHAR(50)   
  
   DECLARE @cExecStatements nvarchar(4000),   
           @cExecArguments    nvarchar(4000)   
  
  
   DECLARE Field_Attr_Cur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
   SELECT RTRIM(c.name)  
   FROM SYSOBJECTS o WITH (NOLOCK)   
   INNER JOIN SYSCOLUMNS c WITH (NOLOCK) ON (o.id = c.id and o.type = 'U')   
   JOIN (SELECT REPLACE(ID, 'I_Field', 'FieldAttr') AS ColName 
         FROM [RDT].[RDTXML_Elm] WITH (NOLOCK)
         WHERE mobile = @nMobile 
         AND   ID IS NOT NULL) AS RDT ON RDT.ColName =  c.name   
   WHERE o.name = 'RDTMOBREC'   
   -- AND LEFT(c.name,9) = 'FieldAttr'  
   AND  EXISTS(SELECT 1 FROM SYSTYPES t WITH (NOLOCK) WHERE (c.xtype = t.xtype)) 
   ORDER BY c.colid, c.name  
  
   OPEN Field_Attr_Cur  
  
   FETCH NEXT FROM Field_Attr_Cur INTO @cColName  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
        SELECT @cFldNum = RIGHT(RTRIM(@cColName),2)  
  
        SET @cFieldName = 'I_Field' + @cFldNum
        
        SET @cExecStatements = ''  
        SET @cExecArguments = ''  
  
        SET @cExecStatements = N'SELECT @cFieldAttr = ' + RTRIM(@cColName) + ' FROM RDT.RDTMOBREC (NOLOCK)'  
                               + 'WHERE MOBILE = ' + CAST(@nMobile as CHAR)  
  
        SET @cExecArguments = N'@cColName NVARCHAR(20), ' +   
                               '@nMobile INT, '             +  
                               '@cFieldAttr NVARCHAR(1) OUTPUT '    
  
  
        EXEC sp_ExecuteSql @cExecStatements, @cExecArguments   
                          ,@cColName  
                          ,@nMobile  
                          ,@cFieldAttr  OUTPUT        
  
  
         DECLARE XML_ELM_Cur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
         SELECT typ,  
                x,  
                y,  
                length,  
                [id],  
                [default],  
                type,  
                value  
         FROM RDT.[RDTXML_Elm] (NOLOCK)  
         WHERE Mobile = @nMobile  
         AND   [ID] IS NOT NULL   
         --AND   RIGHT([ID],2) = @cFldNum  
         AND   ID = @cFieldName 
         Order by y, x  
        
         OPEN XML_ELM_Cur  
        
         FETCH NEXT FROM XML_ELM_Cur INTO @cTyp, @cX, @cY, @cLength, @cID, @cDefault, @cType, @cValue  
        
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            -- Update if @cUpdFlag = O  
            IF @cFieldAttr = 'O'   
            BEGIN  
               UPDATE RDT.[RDTXML_Elm] WITH (ROWLOCK)   
                  SET [ID]      = 'NULL',   
                      Typ       = 'output',    
                      Length    = 'NULL',   
                      [Default] = 'NULL',   
                      Value     = CASE WHEN ISNULL(@cDefault, '') <> '' THEN @cDefault  
                                  ELSE '' END  
                WHERE Mobile = @nMobile  
                AND   [ID]   = @cID  
                AND   Typ = 'input'  
            END  
            ELSE IF @cFieldAttr = 'P' -- Update if @cUpdFlag = P  
            BEGIN  
               UPDATE RDT.[RDTXML_Elm] WITH (ROWLOCK)   
                  SET Typ       = 'password',    
                      Value     = 'NULL'  
                WHERE Mobile = @nMobile  
                AND   [ID]   = @cID  
                AND   Typ = 'input'  
            END  
                
           FETCH NEXT FROM XML_ELM_Cur INTO @cTyp, @cX, @cY, @cLength, @cID, @cDefault, @cType, @cValue  
         END  
        
         CLOSE XML_ELM_Cur  
         DEALLOCATE XML_ELM_Cur  
  
      FETCH NEXT FROM Field_Attr_Cur INTO @cColName  
   END  
     
   CLOSE Field_Attr_Cur  
   DEALLOCATE Field_Attr_Cur  
      

GO