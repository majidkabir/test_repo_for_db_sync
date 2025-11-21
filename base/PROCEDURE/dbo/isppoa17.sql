SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispPOA17                                                */
/* Creation Date: 2020-12-29                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-15963 - JP_HMCOS_PostAllocationSP_CR                    */
/*        :                                                             */
/* Called By: StorerConfig.ConfigKey = PostAllocationSP                 */    
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2020-12-29  Wan      1.0   Created                                   */
/************************************************************************/
CREATE PROC [dbo].[ispPOA17]
     @c_OrderKey    NVARCHAR(10) = ''   
   , @c_LoadKey     NVARCHAR(10) = ''  
   , @c_Wavekey     NVARCHAR(10) = ''  
   , @b_Success     INT           OUTPUT      
   , @n_Err         INT           OUTPUT      
   , @c_ErrMsg      NVARCHAR(250) OUTPUT      
   , @b_debug       INT = 0      
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_Storerkey       NVARCHAR(15) = ''
         , @c_Orderkey_ITF    NVARCHAR(10) = ''
         , @c_Tablename       NVARCHAR(30) = ''

         , @CUR_ORD           CURSOR

   DECLARE @tORDER   TABLE
         ( Orderkey  NVARCHAR(10)   NOT NULL PRIMARY KEY
         , Storerkey NVARCHAR(15)   NOT NULL DEFAULT('')         
         , [Status]  NVARCHAR(10)   NOT NULL DEFAULT('')
         )  

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''


   IF @c_Orderkey <> ''
   BEGIN
      INSERT INTO @tORDER (Orderkey, Storerkey, [Status])
      SELECT OH.Orderkey
            ,OH.StorerKey
            ,OH.[Status]
      FROM ORDERS OH WITH (NOLOCK)
      WHERE OH.Orderkey = @c_ORderkey
   END
   ELSE
   BEGIN
      INSERT INTO @tORDER (Orderkey, Storerkey, [Status])
      SELECT DISTINCT 
             OH.Orderkey
            ,OH.StorerKey
            ,OH.[Status]
      FROM LOADPLANDETAIL LPD WITH (NOLOCK)
      JOIN ORDERS OH WITH (NOLOCK) ON LPD.Orderkey = OH.Orderkey
      WHERE LPD.Loadkey = @c_Loadkey
   END

   SET @CUR_ORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Orderkey
         ,Storerkey
   FROM   @tORDER
   WHERE  [Status] = '1'
   ORDER BY Orderkey
   
   OPEN @CUR_ORD
   
   FETCH NEXT FROM @CUR_ORD INTO @c_Orderkey_ITF, @c_Storerkey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_Tablename = 'WSORDSHORTAGE'
      EXEC ispGenTransmitLog2 @c_Tablename, @c_Orderkey_ITF, '', @c_StorerKey, ''          
                              , @b_success OUTPUT          
                              , @n_err OUTPUT          
                              , @c_errmsg OUTPUT          
                               
      IF @b_success <> 1          
      BEGIN          
         SET @n_continue = 3          
         SET @n_err = 60010          
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +           
                       + ': Insert into TRANSMITLOG2 Failed. (ispPOA17) '
                       + '( SQLSvr MESSAGE = ' + @c_errmsg + ' ) '          
         GOTO QUIT_SP          
      END 
      FETCH NEXT FROM @CUR_ORD INTO @c_Orderkey_ITF, @c_Storerkey
   END
   CLOSE @CUR_ORD
   DEALLOCATE @CUR_ORD  

QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPOA17'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO