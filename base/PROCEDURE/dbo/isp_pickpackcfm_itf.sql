SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_PickPackCfm_ITF                                     */
/* Creation Date: 25-SEP-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-3021 - CN&SG Logitech pack confirmation trigger point   */
/*        :                                                             */
/* Called By: isp_Insert_Packing_DropID                                 */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_PickPackCfm_ITF]
           @c_Storerkey          NVARCHAR(15)
         , @c_PickSlipNo         NVARCHAR(10)
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
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_Orderkey        NVARCHAR(10)
         , @c_Loadkey         NVARCHAR(10)
         , @c_Facility        NVARCHAR(5)

         , @c_ITFConfig       NVARCHAR(30)
         , @c_Tablename       NVARCHAR(30)
         , @c_Key1            NVARCHAR(10)
         , @c_Key2            NVARCHAR(30)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_Orderkey = ''
   SET @c_Loadkey  = ''
   SELECT @c_Orderkey = PH.ORderkey
         ,@c_Loadkey  = PH.Loadkey
   FROM PACKHEADER PH WITH (NOLOCK)
   WHERE PH.PickSlipNo = @c_PickSlipNo

   SET @c_Facility = ''

   IF @c_Orderkey <> '' 
   BEGIN
      SELECT @c_Facility  = OH.Facility
      FROM ORDERS OH WITH (NOLOCK)
      WHERE OH.Orderkey = @c_Orderkey
   END

   IF @c_Facility = ''
   BEGIN
      SELECT @c_Facility  = OH.Facility
      FROM ORDERS OH WITH (NOLOCK)
      WHERE OH.Loadkey = @c_Loadkey
   END

   EXECUTE dbo.nspGetRight @c_Facility  
                        ,  @c_StorerKey         -- Storer  
                        ,  ''                   -- Sku  
                        ,  'PNPCFMLOG'          -- ConfigKey  
                        ,  @b_success    OUTPUT  
                        ,  @c_ITFConfig  OUTPUT  
                        ,  @n_err        OUTPUT  
                        ,  @c_errmsg     OUTPUT  

   IF @b_success <> 1
   BEGIN
      SET @n_continue = 3  
      SET @n_err = 68010  
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +   
                        ': Error Executing nspGetRight. (isp_PickPackCfm_ITF) '  
      GOTO QUIT_SP 
   END

   IF @c_ITFConfig = '1'
   BEGIN
      SET @c_Tablename = 'PNPCFMLOG'
      SET @c_Key1 = @c_PickSlipNo

      IF @c_Orderkey <> ''
      BEGIN
         SET @c_Key2 = 'O' + RTRIM(@c_Orderkey)
      END
      ELSE 
      BEGIN
         SET @c_Key2 = 'L' + RTRIM(@c_Loadkey)
      END

      EXEC ispGenTransmitLog3 @c_Tablename, @c_Key1, @c_Key2, @c_StorerKey, ''  
                              , @b_success   OUTPUT  
                              , @n_err       OUTPUT  
                              , @c_errmsg    OUTPUT  
                   
      IF @b_success <> 1  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err = 68020  
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +   
                           ': Insert into TRANSMITLOG3 Failed. (isp_PickPackCfm_ITF) ( SQLSvr MESSAGE = ' +   
                           ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_PickPackCfm_ITF'
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