SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetPackADByCaseCnt_Wrapper                          */
/* Creation Date: 2020-06-25                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-13503 - SG - Prestige - Packing [CR]                    */
/*        :                                                             */
/* Called By: Normal packing - Packdetail ItemChanged                   */
/*          : of_getantidiversionlines                                  */
/*          : SubSP ispPackADByCS01                                     */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_GetPackADByCaseCnt_Wrapper]
           @c_Orderkey           NVARCHAR(10)
         , @n_CartonNo           INT
         , @c_Storerkey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(20)
         , @n_Qty                INT
         , @n_ADLines            INT = 0        OUTPUT  
         , @n_Explode            INT = 0        OUTPUT 
         , @b_Success            INT            OUTPUT
         , @n_Err                INT            OUTPUT
         , @c_ErrMsg             NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt                INT   = @@TRANCOUNT
         , @n_Continue                 INT   = 1

         , @c_Facility                 NVARCHAR(5)  = ''

         , @c_AntiDiversionByCaseCnt   NVARCHAR(30) = ''
         , @c_PackADByCS_SP            NVARCHAR(30) = ''
         , @c_SQL                      NVARCHAR(4000) = ''
         , @c_SQLParms                 NVARCHAR(1000) = ''

   SET @b_Success       = 1      
   SET @n_Err           = 0
   SET @c_Errmsg        = ''

   SELECT @c_Facility = Facility  
   FROM ORDERS WITH (NOLOCK) 
   WHERE Orderkey = @c_Orderkey

   EXEC nspGetRight
      @c_Facility   = @c_Facility  
   ,  @c_StorerKey  = @c_StorerKey 
   ,  @c_sku        = ''       
   ,  @c_ConfigKey  = 'AntiDiversionByCaseCnt' 
   ,  @b_Success    = @b_Success                OUTPUT
   ,  @c_authority  = @c_AntiDiversionByCaseCnt OUTPUT 
   ,  @n_err        = @n_err                    OUTPUT
   ,  @c_errmsg     = @c_errmsg                 OUTPUT
   ,  @c_Option1    = @c_PackADByCS_SP          OUTPUT

   IF @b_success <> 1  
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 70010   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (isp_GetPackADByCaseCnt_Wrapper)'   
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT_SP  
   END 

   IF @c_AntiDiversionByCaseCnt = '0'
   BEGIN
      GOTO QUIT_SP
   END

   SET @n_Explode = 1 

   SET @c_PackADByCS_SP = ISNULL(RTRIM(@c_PackADByCS_SP),'')

   IF @c_PackADByCS_SP = '0'
   BEGIN
      GOTO QUIT_SP
   END
   
   IF EXISTS (SELECT 1 FROM sys.objects (NOLOCK) where object_id = object_id(@c_PackADByCS_SP))
   BEGIN
      SET @c_SQL  = N'EXEC ' + @c_PackADByCS_SP 
                  + ' @c_Orderkey   = @c_Orderkey'
                  + ',@n_CartonNo   = @n_CartonNo'
                  + ',@c_Storerkey  = @c_Storerkey'
                  + ',@c_Sku        = @c_Sku'
                  + ',@n_Qty        = @n_Qty'
                  + ',@n_ADLines    = @n_ADLines         OUTPUT'
                  + ',@n_Explode    = @n_Explode         OUTPUT'
                  + ',@b_Success    = @b_Success         OUTPUT'
                  + ',@n_Err        = @n_Err             OUTPUT'
                  + ',@c_ErrMsg     = @c_ErrMsg          OUTPUT'

      SET @c_SQLParms= N'@c_Orderkey   NVARCHAR(10) '
                     + ',@n_CartonNo   INT '
                     + ',@c_Storerkey  NVARCHAR(15) '
                     + ',@c_Sku        NVARCHAR(20) '
                     + ',@n_Qty        INT'
                     + ',@n_ADLines    INT            OUTPUT'
                     + ',@n_Explode    INT            OUTPUT'
                     + ',@b_Success    INT            OUTPUT'
                     + ',@n_Err        INT            OUTPUT'
                     + ',@c_ErrMsg     NVARCHAR(255)  OUTPUT'

      EXEC sp_executesql @c_SQL
                        ,@c_SQLParms  
                        ,@c_Orderkey 
                        ,@n_CartonNo   
                        ,@c_Storerkey     
                        ,@c_Sku   
                        ,@n_Qty        
                        ,@n_ADLines       OUTPUT
                        ,@n_Explode       OUTPUT
                        ,@b_Success       OUTPUT
                        ,@n_Err           OUTPUT
                        ,@c_ErrMsg        OUTPUT

      IF @b_Success = 0 
      BEGIN
         SET @n_continue = 3  
         SET @n_err = 70020   
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing ' + @c_PackADByCS_SP + '. (isp_GetPackADByCaseCnt_Wrapper)'   
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
         GOTO QUIT_SP  
      END
   END
   
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetPackADByCaseCnt_Wrapper'
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