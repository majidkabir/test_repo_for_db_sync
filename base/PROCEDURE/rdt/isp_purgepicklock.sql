SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_PurgePickLock                                  */
/* Creation Date: 27-May-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: Leong                                                    */
/*                                                                      */
/* Purpose:  Purge records exceed retention period from rdtPickLock     */
/*           by Status, AddDate or EditDate                             */
/*                                                                      */
/* Input Parameters:  @cDateType - Indicator for 1.AddDate / 2.EditDate */
/*                    @cStatus   - Specific Status to be purge          */
/*                    @nDays     - # of days to retain                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  Set under Scheduler Jobs.                                */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author      Ver     Purposes                             */
/* 27-May-2009 Leong       1.0     SOS#137631 - Requested               */
/* 18-May-2010 TLTING      1.1     Change Schema                        */		
/************************************************************************/

CREATE PROC [RDT].[isp_PurgePickLock]      
   @cDateType  NVARCHAR(1),
   @cStatus    NVARCHAR(1),
   @nDays      Int
AS    
BEGIN    
SET CONCAT_NULL_YIELDS_NULL OFF    
SET QUOTED_IDENTIFIER OFF    
SET NOCOUNT ON    
 
DECLARE @b_success              Int
      , @c_Condition            NVARCHAR(510)     
      , @cExecStatements        NvarChar(2000)
      , @cExecArguments         NvarChar(2000)
      , @nRowRef                Int
      , @b_debug                Int
    
SELECT  @b_success = 1
      , @cExecStatements = ''
      , @b_debug = 0
      , @c_Condition = ''
 
IF ISNULL(RTRIM(@cDateType),'') = '1' -- AddDate
BEGIN
   SELECT @c_Condition = " AND (DateDiff(DAY, EditDate, GetDate())) > " + RTRIM(LTRIM(@nDays)) + " "
END

IF ISNULL(RTRIM(@cDateType),'') = '2' -- EditDate
BEGIN
   SELECT @c_Condition = " AND (DateDiff(DAY, EditDate, GetDate())) > " + RTRIM(LTRIM(@nDays)) + " "
END

IF @b_debug = 1    
BEGIN    
   SELECT  @c_Condition 'Start Purging records for @c_Condition'     
END 
   
BEGIN
   SELECT @cExecStatements = N'DECLARE PurgeTableCur CURSOR READ_ONLY FAST_FORWARD FOR ' +
                              ' SELECT RowRef FROM rdt.rdtPickLock WITH (NOLOCK) ' +    
                              ' WHERE Status = N''' + ISNULL(RTRIM(@cStatus),'') + ''' ' +    
                                @c_Condition +
                              ' ORDER BY RowRef '

   EXEC sp_executesql @cExecStatements     
   
   OPEN PurgeTableCur
   
   FETCH NEXT FROM PurgeTableCur INTO @nRowRef
   
   WHILE @@fetch_status <> -1    
   BEGIN
      SELECT @cExecStatements = N'DELETE rdt.rdtPickLock ' +     
             ' WHERE RowRef = ' + CONVERT(VarChar(15), @nRowRef) + ' ' 
       
      BEGIN TRAN
         EXEC sp_executesql @cExecStatements 
      COMMIT TRAN
       
      FETCH NEXT FROM PurgeTableCur INTO @nRowRef
      END
  
   CLOSE PurgeTableCur     
   DEALLOCATE PurgeTableCur  
   END -- WHILE @@fetch_status <> -1
   
   IF @b_debug = 1    
   BEGIN    
      SELECT 'Purging Completed ! '    
   END

END -- procedure

GO