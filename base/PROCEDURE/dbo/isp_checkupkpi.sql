SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_CheckUpKPI                                     */
/* Copyright: IDS                                                       */
/* Written by: KHLim                                                     */
/* Purpose: generate CheckUpKPIDet                                      */
/* Called By: BEJ - Check Up KPI                                        */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2013-Oct-09  WTShong       enhancement                               */
/* 2017-Mar-21  TLTING        performance Tune                          */
/* 2017-Apr-04  TLTING        extend value decimal length               */
/* 2017-Apr-25  TLTING        correction on hour filtering              */
/* 2017-May-04  KHLim    log dynamic SQL statement & create view (KH01) */
/************************************************************************/
CREATE PROC [dbo].[isp_CheckUpKPI]  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   SET ANSI_NULLS OFF 
   SET ANSI_WARNINGS OFF  
  
   DECLARE   @cFacility          NVARCHAR(5)  
            ,@cStorerKey         NVARCHAR(20)  
            ,@nKPI               INT  
            ,@nCnt               DECIMAL(25,3)  
            ,@cExecStatements    NVARCHAR(4000)  
            ,@cExecArguments     NVARCHAR(4000)  
            ,@dRunDate           DATETIME  
            ,@cSELECT            NVARCHAR(4000)              
            ,@cWHERE             NVARCHAR(4000)     
            ,@cInsFacility       NVARCHAR(5)  
            ,@cInsStorer         NVARCHAR(20)           
            ,@n_debug            INT 
            ,@n_Err              INT            --KH01
            ,@c_ErrMsg           NVARCHAR(255)  --KH01
            ,@c_AlertKey         char(18)       --KH01
            ,@dBegin             DATETIME       --KH01
            ,@nErrSeverity       INT            --KH01
            ,@nErrState          INT            --KH01
  
   SET @cFacility = ''  
   SET @cStorerKey = ''  
   SET @n_debug   = 0  
  
   DECLARE CUR_FacilityStorer CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT LOC.Facility, SKUxLOC.StorerKey   
   FROM SKUxLOC WITH (NOLOCK)   
   JOIN LOC WITH (NOLOCK) ON LOC.Loc = SKUxLOC.Loc   
   WHERE LOC.Facility <> ''   
   AND SKUxLOC.Qty > 0   
   UNION ALL   
   SELECT '', ''   
     
   OPEN CUR_FacilityStorer  
     
   FETCH NEXT FROM CUR_FacilityStorer INTO @cFacility, @cStorerKey    
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      IF @n_debug = 1  
      BEGIN  
         SELECT @cStorerKey '@cStorerKey', @cFacility '@cFacility'   
      END  
      SET @nCnt = 0  
  
      DECLARE CUR_KPI CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT KPI, SQL  
      FROM  CheckUpKPI WITH (nolock)  
      WHERE SQL <> ''   
      AND   KPICode <> 'Data Aging Issues'      -- KIV the SQL, to be modified later...  
      ORDER BY TypeOfSymbol, KPI   -- process nonpercentage KPIs first because KPI with percentage need to use the Value of nonpercentage KPIs  
  
      OPEN CUR_KPI  
  
      FETCH NEXT FROM CUR_KPI INTO @nKPI, @cExecStatements   
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         IF @n_debug = 1  
         BEGIN  
            SELECT CAST(@nKPI AS VARCHAR) '@nKPI'  
         END 

         IF CHARINDEX('FinalValue',@cExecStatements) > 0  
         BEGIN  
            SET @cExecStatements = REPLACE(@cExecStatements,'FinalValue', '@nCnt')  
         END  
         ELSE IF CHARINDEX('group by ',@cExecStatements) > 0    -- IF SQL contains group by, use @@ROWCOUNT, ELSE use COUNT(*) to get quicker result  
         BEGIN  
            SET @cSELECT = SUBSTRING(@cExecStatements, 1, CHARINDEX('FROM ',@cExecStatements) - 1)  
            SET @cWhere =           
            CASE WHEN CHARINDEX('order by ',@cExecStatements) > 0 THEN  
           SUBSTRING(@cExecStatements, CHARINDEX('FROM ',@cExecStatements), CHARINDEX('order by ',@cExecStatements)-CHARINDEX('FROM ',@cExecStatements))  
                                 ELSE  
                                    SUBSTRING(@cExecStatements, CHARINDEX('FROM ',@cExecStatements), LEN(@cExecStatements)+1-CHARINDEX('FROM ',@cExecStatements))  
                                 END  
  
            SET @cExecStatements = @cSELECT +   
                                    ' INTO #RESULT ' + CHAR(13) +   
                                    @cWhere + ';' +   
                                    + ' SELECT @nCnt = COUNT(*) FROM #RESULT  '  
                                               
         END  
         ELSE  
         BEGIN  
            SET @cExecStatements =   
                               + ' SELECT @nCnt = COUNT(*)  '   --testing comment out this line  
                               + CASE WHEN CHARINDEX('order by ',@cExecStatements) > 0 THEN  
                                    SUBSTRING(@cExecStatements, CHARINDEX('FROM ',@cExecStatements), CHARINDEX('order by ',@cExecStatements)-CHARINDEX('FROM ',@cExecStatements))  
                                 ELSE  
                                    SUBSTRING(@cExecStatements, CHARINDEX('FROM ',@cExecStatements), LEN(@cExecStatements)+1-CHARINDEX('FROM ',@cExecStatements))  
                                 END  
         END  
  
         SET @cExecArguments = N'@cStorerKey NVARCHAR(20), @cFacility NVARCHAR(5), @nCnt Decimal(25,3) OUTPUT'  
  
         SET @nCnt = 0  
         IF CHARINDEX('@cStorerKey',@cExecStatements) = 0   
            SET @cInsStorer = ''  
         ELSE   
            SET @cInsStorer = @cStorerKey   
  
         IF CHARINDEX('@cFacility',@cExecStatements) = 0   
            SET @cInsFacility = ''  
         ELSE   
            SET @cInsFacility = @cFacility   
  
  
         IF NOT EXISTS(SELECT 1 FROM CheckUpKPIDetail WITH (NOLOCK) WHERE KPI = @nKPI AND StorerKey = @cInsStorer AND Facility = @cInsFacility  
                       AND RunDate >  DATEAdd(hour, -23 , GETDATE())  )  
         BEGIN  
            SELECT @nErrSeverity = '', @c_ErrMsg = '', @n_Err = 0   --KH01
            BEGIN TRY   --KH01
               SET @dBegin = GETDATE() --KH01
               EXEC sp_ExecuteSql  @cExecStatements  
                                 , @cExecArguments  
                                 , @cStorerKey  
                                 , @cFacility  
                                 , @nCnt OUTPUT  
            END TRY
            BEGIN CATCH --KH01
               SET @n_Err        = ERROR_NUMBER()
               SET @c_ErrMsg     = ERROR_MESSAGE();
               SET @nErrSeverity = ERROR_SEVERITY();
               SET @nErrState    = ERROR_STATE();
               RAISERROR ( @c_ErrMsg, @nErrSeverity, @nErrState );
            END CATCH
            IF OBJECT_ID('ALERT','u') IS NOT NULL  --KH11
            BEGIN
               EXECUTE nspg_getkey 'LogEvent', 18, @c_AlertKey OUTPUT, '', '', ''
               INSERT ALERT(AlertKey, ModuleName          ,AlertMessage,Severity     ,NotifyId   ,Status,ResolveDate, Resolution     ,  Storerkey, Qty ,UOMQty,Loc) 
               VALUES   (@c_AlertKey,OBJECT_NAME(@@PROCID),@c_ErrMsg   ,@nErrSeverity,HOST_NAME(),@n_err,@dBegin    ,@cExecStatements,@cStorerKey,@nCnt,@nKPI ,@cFacility)
            END
  
            IF ISNULL(@nCnt, 0) > 0   
            BEGIN   
               SET @dRunDate = GETDATE()  
                               
               INSERT INTO CheckUpKPIDetail   
                  ( KPI, Type, StorerKey, Facility, Field, Value, RunDate )  
               VALUES   
                  ( @nKPI, 'RefreshALL', @cInsStorer, @cInsFacility, 'COUNT', @nCnt, @dRunDate)  
  
            END   
         END  
  
         FETCH NEXT FROM CUR_KPI INTO @nKPI, @cExecStatements   
      END -- WHILE  
      CLOSE CUR_KPI  
      DEALLOCATE CUR_KPI  
        
      FETCH NEXT FROM CUR_FacilityStorer INTO @cFacility, @cStorerKey   
   END  
   CLOSE CUR_FacilityStorer  
   DEALLOCATE CUR_FacilityStorer   
     
  
  
   UPDATE  CheckUpKPI WITH (rowlock)  
   SET LastRunDate = @dRunDate  
   WHERE SQL <> ''   
   AND   KPICode <> 'Data Aging Issues'      -- KIV the SQL, to be modified later...  
  
END  

GO