SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Trigger: ntrSkuInfoUpdate                                               */
/* Creation Date: 22-May-2012                                              */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose:  Update other transactions while SkuInfo line is to be updated.*/
/*                                                                         */
/* Return Status:                                                          */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Called By: When records Updated                                         */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Modifications:                                                          */
/* Date         Author   Ver  Purposes                                     */
/* 22-May-2012  MCTang   1.0  Initial                                      */
/* *********************************************************************** */
/* 23-Sep-2013  YokeBeen 1.1  Base on PVCS SQL2005_Unicode version 1.1.    */
/*                            FBR#290176 - Insert TransmitLog3.Key2 = "0"  */
/*                            for trigger point "UPDSINFLOG" - (YokeBeen01)*/
/* 28-Oct-2013  TLTING   1.2  Review Editdate column update                */
/***************************************************************************/

CREATE TRIGGER ntrSkuInfoUpdate ON SkuInfo
FOR UPDATE
AS
BEGIN
 IF @@ROWCOUNT = 0
 BEGIN
 RETURN
 END 
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SET @b_debug = 0

   IF @b_debug = 2
   BEGIN
      DECLARE @profiler NVARCHAR(80)
      SELECT  @profiler = 'PROFILER,637,00,0,ntrSkuInfoUpdate Trigger' + CONVERT(NVARCHAR(12), GETDATE(), 114)
      PRINT   @profiler
   END

   DECLARE @b_Success   Int                  -- Populated by calls to stored procedures - was the proc successful?
         , @n_Err       Int                  -- Error number returned by stored procedure or this trigger
         , @c_ErrMsg    NVARCHAR(250)        -- Error message returned by stored procedure or this trigger
         , @n_Continue  Int
         , @n_StartTCnt Int                  -- Holds the current transaction count
         , @n_Cnt       Int

   DECLARE @c_Storerkey                NVARCHAR(15)
         , @c_Sku                      NVARCHAR(20)
         , @c_FieldName                NVARCHAR(25)
         , @c_Authority_UpdSInfoLog    NVARCHAR(1)      
         , @c_ListName_UpdSInfoLog     NVARCHAR(10)       
         , @c_ConfigKey_UpdSInfoLog    NVARCHAR(30)       
         , @c_UpdateColumn             NVARCHAR(4000)     
         , @c_Found                    NVARCHAR(1)           
    
   SELECT @n_Continue=1, @n_StartTCnt=@@TRANCOUNT

   SET @c_Storerkey             = ''
   SET @c_Sku                   = ''
   SET @c_ListName_UpdSInfoLog  = 'TRTL3SINF'           
   SET @c_ConfigKey_UpdSInfoLog = 'UPDSINFLOG'         

   IF ( @n_Continue=1 OR @n_Continue=2 ) AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE SkuInfo
      SET    EditDate = GetDate(),
             EditWho  = SUSER_SNAME()
      FROM   INSERTED
      WHERE  SkuInfo.StorerKey = INSERTED.StorerKey
      AND    SkuInfo.SKU = INSERTED.SKU

      SELECT @n_Err = @@ERROR, @n_Cnt = @@ROWCOUNT

      IF @n_Err <> 0
      BEGIN
         SELECT @n_Continue = 3
         SELECT @c_ErrMsg = CONVERT(NVARCHAR(250),@n_Err), @n_Err=63703 
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))+': Update Failed On Table SKU. (ntrSkuInfoUpdate)' + ' ( '
                          + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)),'') + ' ) '
      END
   END --IF @n_Continue=1 OR @n_Continue=2

   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_Continue = 4
   END

   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN
      DECLARE C_Inserted_SkuInfo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT
             INSERTED.Storerkey,
             INSERTED.Sku
      FROM   INSERTED
 
      OPEN C_Inserted_SkuInfo
      FETCH NEXT FROM C_Inserted_SkuInfo INTO @c_Storerkey, @c_Sku

      WHILE @@FETCH_STATUS <> -1
      BEGIN

         SET @b_success = 0
         SET @c_Authority_UpdSInfoLog = '0'

         EXECUTE dbo.nspGetRight  
                   ''                       -- Facility
                 , @c_StorerKey             -- Storer
                 , ''                       -- Sku
                 , @c_ConfigKey_UpdSInfoLog -- ConfigKey
                 , @b_success               OUTPUT
                 , @c_Authority_UpdSInfoLog OUTPUT
                 , @n_Err                   OUTPUT
                 , @c_ErrMsg                OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_ErrMsg = CONVERT(NVARCHAR(250),@n_Err), @n_Err=63801
            SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                             + ': Retrieve of Right (UPDSINFLOG) Failed (ntrSkuInfoUpdate) ( SQLSvr MESSAGE='
                             + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '
         END
         
         IF @c_Authority_UpdSInfoLog = '1'
         BEGIN     
            SET @c_UpdateColumn = ''

            SELECT @c_UpdateColumn = CASE WHEN INSERTED.ExtendedField01 <> DELETED.ExtendedField01 THEN 'ExtendedField01|' ELSE '' END    
                                   + CASE WHEN INSERTED.ExtendedField02 <> DELETED.ExtendedField02 THEN 'ExtendedField02|' ELSE '' END    
                                   + CASE WHEN INSERTED.ExtendedField03 <> DELETED.ExtendedField03 THEN 'ExtendedField03|' ELSE '' END    
                                   + CASE WHEN INSERTED.ExtendedField04 <> DELETED.ExtendedField04 THEN 'ExtendedField04|' ELSE '' END    
                                   + CASE WHEN INSERTED.ExtendedField05 <> DELETED.ExtendedField05 THEN 'ExtendedField05|' ELSE '' END    
                                   + CASE WHEN INSERTED.ExtendedField06 <> DELETED.ExtendedField06 THEN 'ExtendedField06|' ELSE '' END    
                                   + CASE WHEN INSERTED.ExtendedField07 <> DELETED.ExtendedField07 THEN 'ExtendedField07|' ELSE '' END    
                                   + CASE WHEN INSERTED.ExtendedField08 <> DELETED.ExtendedField08 THEN 'ExtendedField08|' ELSE '' END    
                                   + CASE WHEN INSERTED.ExtendedField09 <> DELETED.ExtendedField09 THEN 'ExtendedField09|' ELSE '' END    
                                   + CASE WHEN INSERTED.ExtendedField10 <> DELETED.ExtendedField10 THEN 'ExtendedField10|' ELSE '' END    
                                   + CASE WHEN INSERTED.ExtendedField11 <> DELETED.ExtendedField11 THEN 'ExtendedField11|' ELSE '' END    
                                   + CASE WHEN INSERTED.ExtendedField12 <> DELETED.ExtendedField12 THEN 'ExtendedField12|' ELSE '' END    
                                   + CASE WHEN INSERTED.ExtendedField13 <> DELETED.ExtendedField13 THEN 'ExtendedField13|' ELSE '' END    
                                   + CASE WHEN INSERTED.ExtendedField14 <> DELETED.ExtendedField14 THEN 'ExtendedField14|' ELSE '' END    
                                   + CASE WHEN INSERTED.ExtendedField15 <> DELETED.ExtendedField15 THEN 'ExtendedField15|' ELSE '' END    
                                   + CASE WHEN INSERTED.ExtendedField16 <> DELETED.ExtendedField16 THEN 'ExtendedField16|' ELSE '' END 
                                   + CASE WHEN INSERTED.ExtendedField17 <> DELETED.ExtendedField17 THEN 'ExtendedField17|' ELSE '' END  
                                   + CASE WHEN INSERTED.ExtendedField18 <> DELETED.ExtendedField18 THEN 'ExtendedField18|' ELSE '' END  
                                   + CASE WHEN INSERTED.ExtendedField19 <> DELETED.ExtendedField19 THEN 'ExtendedField19|' ELSE '' END  
                                   + CASE WHEN INSERTED.ExtendedField20 <> DELETED.ExtendedField20 THEN 'ExtendedField20|' ELSE '' END     
            FROM  INSERTED, DELETED 
            WHERE INSERTED.StorerKey = DELETED.StorerKey 
            AND   INSERTED.SKU       = DELETED.SKU
            AND   INSERTED.Storerkey = @c_Storerkey 
            AND   INSERTED.SKU       = @c_SKU

            IF @c_UpdateColumn <> ''   
            BEGIN

               SET @c_Found = 'N'

               DECLARE C_CodeLkUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT ISNULL(RTRIM(Code), '')
               FROM   CodeLkUp WITH (NOLOCK)
               WHERE  ListName  = @c_ListName_UpdSInfoLog
               AND    StorerKey = @c_StorerKey
          
               OPEN C_CodeLkUp
               FETCH NEXT FROM C_CodeLkUp INTO @c_FieldName

               WHILE @@FETCH_STATUS <> -1
               BEGIN

                  SET @c_FieldName = '%' + UPPER(@c_FieldName) + '|' + '%'

                  SELECT @c_Found = CASE WHEN UPPER(@c_UpdateColumn) like @c_FieldName THEN 'Y' ELSE 'N' END

                  IF @c_Found  = 'Y'
                  BEGIN
                     BREAK
                  END

                  FETCH NEXT FROM C_CodeLkUp INTO @c_FieldName
               END -- WHILE @@FETCH_STATUS <> -1
               CLOSE C_CodeLkUp
               DEALLOCATE C_CodeLkUp

               IF @c_Found = 'Y'
               BEGIN   
                  EXEC dbo.ispGenTransmitLog3 @c_ConfigKey_UpdSInfoLog, @c_StorerKey, '0', @c_SKU, '' -- (YokeBeen01) 
                                    , @b_success OUTPUT          
                                    , @n_Err OUTPUT          
                                    , @c_ErrMsg OUTPUT          
                  IF @b_success <> 1          
                  BEGIN          
                     SELECT @n_Continue = 3
                     SELECT @c_ErrMsg = CONVERT(NVARCHAR(250),@n_Err), @n_Err=63802
                     SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                                      + ': Insert Into TransmitLog3 Table (UPDSINFLOG) Failed (ntrSkuInfoUpdate)( SQLSvr MESSAGE='
                                      + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '    
                  END           
               END
            END --IF @c_UpdateColumn <> '' 
         END --IF @c_Authority_UpdSInfoLog = '1'

         FETCH NEXT FROM C_Inserted_SkuInfo INTO @c_Storerkey, @c_Sku
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE C_Inserted_SkuInfo
      DEALLOCATE C_Inserted_SkuInfo
   END  --IF @n_Continue = 1 OR @n_Continue = 2  

QUIT:
   /* #INCLUDE <TRRDA2.SQL> */
   IF @n_Continue=3  
   BEGIN
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ntrSkuInfoUpdate'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012

      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,637,00,9,ntrSkuInfoUpdate Tigger, ' + CONVERT(NVARCHAR(12), getdate(), 114)
         PRINT @profiler
      END
      RETURN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END

      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,637,00,9,ntrSkuInfoUpdate Trigger, ' + CONVERT(NVARCHAR(12), getdate(), 114) PRINT @profiler
      END
      RETURN
   END
END

GO