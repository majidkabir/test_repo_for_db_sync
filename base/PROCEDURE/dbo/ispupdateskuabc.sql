SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispUpdateSkuABC                                    */
/* Copyright : LFL                                                      */
/* Written by: KHLim                                                    */
/* Purpose: [SQL JOB] Auto calculate Product ABC https://jira.lfapps.net/browse/WMS-2283 */
/* Called By: BEJ - Update SKU.ABC Weekly                               */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[ispUpdateSkuABC]  
(   @cStorer  nvarchar(15)
   ,@bDebug   bit         = 0 )
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   SET ANSI_NULLS OFF 
   SET ANSI_WARNINGS OFF  
   DECLARE @nADays         int
         , @nBDays         int
         , @cShort         nvarchar(10)
         , @cLong          nvarchar(250)
         , @cUDF01         nvarchar(60)
         , @cABCnow        nvarchar(5)
         , @cABCNew        nvarchar(5)
         , @nDayDiff       int
         , @cMaterial      nvarchar(9)
         , @cProductModel  nvarchar(30)
         , @cSku           nvarchar(20)
         , @cExecStatements NVARCHAR(4000)
         , @n_Err          INT
         , @c_ErrMsg       NVARCHAR(255)
         , @c_AlertKey     char(18)
         , @nErrSeverity   INT
         , @dBegin         DATETIME
         , @nErrState      INT
         , @cHost          NVARCHAR(128)
         , @cModule        NVARCHAR(128)
         , @cSQL           NVARCHAR(4000)
         , @cArcDB         NVARCHAR(128)

   SET @cModule   = ISNULL(OBJECT_NAME(@@PROCID),'')
   SET @cArcDB    = LEFT(DB_NAME(),2)+'ARCHIVE'

   IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = @cArcDB)
   BEGIN
      SET @c_ErrMsg = 'Invalid Archive DB name: '+@cArcDB
      RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR
      GOTO Quit
   END

   IF  @cModule = ''
      SET @cModule= 'ispUpdateSkuABC'

   SET @cHost     = ISNULL(HOST_NAME(),'')

   SELECT  @cShort = Short
         , @cLong  = Long
         , @cUDF01 = UDF01
   FROM CODELKUP 
   WHERE StorerKey = @cStorer 
    AND LISTNAME   = 'ABCSetup' 
    AND Code       = 'PRODABC'

   IF @@ROWCOUNT = 0
   BEGIN
      SET @c_ErrMsg = 'No record found from CODELKUP!'
      RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR
      GOTO Quit
   END

   IF ISNUMERIC(@cShort) = 1
   BEGIN
      SET @nADays  = CAST(@cShort AS int)
   END
   ELSE
   BEGIN
      SET @c_ErrMsg = 'CODELKUP.Short value is not numeric!'
      RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR
      GOTO Quit
   END

   IF ISNUMERIC(@cLong) = 1
   BEGIN
      SET @nBDays  = CAST(@cLong AS int)
   END
   ELSE
   BEGIN
      SET @c_ErrMsg = 'CODELKUP.Long value is not numeric!'
      RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR
      GOTO Quit
   END

   --IF ISNULL(RTRIM(@cUDF01),'') NOT LIKE 'SKU.SUSR%' AND ISNULL(@cUDF01,'') <> ''
   --BEGIN
   --   SELECT 'CODELKUP.UDF01 value='+ISNULL(@cUDF01,'')+' is non standard (SKU.SUSR1/2/3/4/5). Please check https://jira.lfapps.net/browse/WMS-2283'
   --   GOTO Quit
   --END

   IF OBJECT_ID('tempdb..#TEMP','u') IS NOT NULL
      DROP TABLE #TEMP;

   CREATE TABLE #TEMP(
      Material	NVARCHAR(9)
     ,DayDiff  INT
   )

   SET @cSQL = '
SELECT SUBSTRING(i.SKU,1,9)
      ,DATEDIFF( day, MIN(convert(datetime, i.EditDate, 111)), convert(datetime,getdate(),111) )
FROM ( 
   SELECT Sku, EditDate
   FROM               ITRN AS i WITH (NOLOCK) 
   WHERE StorerKey = '''+@cStorer+''' and TRANTYPE=''WD'' and SOURCETYPE=''ntrpickdetailupdate''
   UNION
   SELECT Sku, EditDate
   FROM '+@cArcDB+'.dbo.ITRN AS i WITH (NOLOCK) 
   WHERE StorerKey = '''+@cStorer+''' and TRANTYPE=''WD'' and SOURCETYPE=''ntrpickdetailupdate'' ) AS i
JOIN SKU  AS s WITH (NOLOCK) ON SUBSTRING(s.SKU,1,9) = SUBSTRING(i.SKU,1,9) 
AND    s.StorerKey = '''+@cStorer+''' AND s.SKUSTATUS = ''ACTIVE''
GROUP BY SUBSTRING(i.SKU,1,9)'

   --DECLARE CUR_IS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   INSERT INTO #TEMP 
   EXEC(@cSQL)

   --OPEN CUR_IS
   --FETCH NEXT FROM CUR_IS INTO @cMaterial, @nDayDiff, @cSUSRcol

   --WHILE @@FETCH_STATUS <> -1
   --BEGIN
   --   SET    @cABCNew = ''
   --   IF      @nDayDiff <= @nADays or  @nDayDiff IS NULL or @cSUSRcol='Y' -- (ISNULL(@cUDF01,'')='SKU.SUSR4' AND @cSUSRcol='Y')
   --   BEGIN
   --      SET @cABCNew = 'A'
   --   END
   --   ELSE IF @nDayDiff <= @nBDays 
   --   BEGIN
   --      SET @cABCNew = 'B'
   --   END
   --   ELSE  
   --   BEGIN
   --      SET @cABCNew = 'C'
   --   END

   --   IF @bDebug = 1
   --   BEGIN
   --      SELECT 'Material'=@cMaterial, '@nDayDiff'=@nDayDiff, '@cSUSRcol'=@cSUSRcol, '@cABCNew'=@cABCNew --, 'UDF01'=@cUDF01
   --   END

   --   IF @cABCNew <> ''
   --   BEGIN
   DECLARE CUR_IS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

   SELECT   t.Material, t.DayDiff, s.ProductModel, x.Sku, s.ABC
         ,CASE WHEN t.DayDiff <= @nADays or t.DayDiff IS NULL or s.ProductModel='EVERYGREEN' THEN 'A'
               WHEN t.DayDiff <= @nBDays                                                     THEN 'B'
                                                                                             ELSE 'C' END
   FROM            SKU     AS s WITH (nolock)
   INNER      JOIN SKUXLOC AS x WITH (nolock) ON x.SKU=s.SKU AND x.StorerKey=s.StorerKey AND x.Qty>0
   LEFT OUTER JOIN #TEMP   AS t WITH (nolock) ON SUBSTRING(x.SKU,1,9) = Material
   WHERE x.StorerKey = @cStorer
   GROUP BY t.Material, t.DayDiff, s.ProductModel, x.Sku, s.ABC, x.StorerKey
   ORDER BY x.Sku

   OPEN CUR_IS
   FETCH NEXT FROM CUR_IS INTO @cMaterial, @nDayDiff, @cProductModel, @cSku, @cABCnow, @cABCNew

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @cABCnow <> @cABCNew
      BEGIN
         SELECT @c_ErrMsg = '', @n_Err = 0, @cExecStatements = ''
         BEGIN TRY
            SET @dBegin = GETDATE()
            UPDATE SKU WITH (ROWLOCK) SET ABC = @cABCNew, TrafficCop = NULL
            WHERE StorerKey = @cStorer AND Sku = @cSku

            SET @cExecStatements =
           'UPDATE SKU WITH (ROWLOCK) SET ABC = @cABCNew, TrafficCop = NULL '+
           'WHERE StorerKey = @cStorer AND Sku = @cSku'
         END TRY
         BEGIN CATCH
            SET @n_Err        = ERROR_NUMBER()
            SET @c_ErrMsg     = ERROR_MESSAGE();
            SET @nErrState    = ERROR_STATE();
            RAISERROR ( @c_ErrMsg, @nErrSeverity, @nErrState );
         END CATCH
         IF OBJECT_ID('ALERT','u') IS NOT NULL
         BEGIN
            EXECUTE nspg_getkey 'LogEvent', 18, @c_AlertKey OUTPUT, '', '', ''
INSERT ALERT(AlertKey,ModuleName,AlertMessage,Severity,UOMQty ,NotifyId,Status,ResolveDate, Resolution     ,Activity  ,Storerkey, Sku ,Qty      ,TaskDetailKey,TaskDetailKey2,UCCNo  ) 
VALUES   (@c_AlertKey,@cModule  ,@c_ErrMsg   ,@nADays ,@nBDays,@cHost  ,@n_err,@dBegin    ,@cExecStatements,@cMaterial,@cStorer ,@cSku,@nDayDiff,@cABCnow     ,@cABCNew      ,LEFT(@cProductModel,20))
         END
      END
      FETCH NEXT FROM CUR_IS INTO @cMaterial, @nDayDiff, @cProductModel, @cSku, @cABCnow, @cABCNew
   END

   CLOSE CUR_IS
   DEALLOCATE CUR_IS
Quit:
   IF OBJECT_ID('tempdb..#TEMP','u') IS NOT NULL
      DROP TABLE #TEMP;
END  

GO