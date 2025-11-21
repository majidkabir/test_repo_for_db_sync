SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_Ecom_UndoPackConfirm                                    */
/* Creation Date: 26-APR-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#361901 - New ECOM Packing                               */
/*        :                                                             */
/* Called By:  n_cst_packheader_ecom                                    */
/*          :  ue_undopackconfirm                                       */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 21-SEP-2016 Wan01    1.1   Performance Tune                          */
/* 01-JUN-2017 Wan02    1.2   WMS-1816 - CN_DYSON_Exceed_ECOM PACKING   */
/************************************************************************/
CREATE PROC [dbo].[isp_Ecom_UndoPackConfirm] 
            @c_PickSlipNo     NVARCHAR(10)
         ,  @b_Success        INT = 0           OUTPUT 
         ,  @n_err            INT = 0           OUTPUT 
         ,  @c_errmsg         NVARCHAR(255) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT
         
         , @c_TaskBatchNo     NVARCHAR(10) 
         , @c_Orderkey        NVARCHAR(10) 

         , @n_RowRef          BIGINT         --(Wan01)

         , @c_Facility                 NVARCHAR(15)   --(Wan01)
         , @c_Storerkey                NVARCHAR(15)   --(Wan02)
         , @c_EPACKNoRVPackIfOrdInMBOL NVARCHAR(30)   --(Wan02)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_Storerkey= ''                      --(Wan02)
   SELECT @c_TaskBatchNo = TaskBatchNo
         ,@c_Orderkey    = Orderkey          --(Wan01)
         ,@c_Storerkey   = Storerkey         --(Wan02)
   FROM PACKHEADER WITH (NOLOCK)
   WHERE  PickSlipNo = @c_PickSlipNo

   IF EXISTS ( SELECT 1 
               FROM PACKHEADER WITH (NOLOCK)
               WHERE TaskBatchNo = @c_TaskBatchNo
               AND Orderkey = '' 
             )
   BEGIN 
      SET @n_continue = 3
      SET @n_err = 60010 
      SET @c_errmsg='NSQL '+CONVERT(char(5),@n_err)+': Packing In Progress. Undo Pack Confirm Abort (isp_Ecom_UndoPackConfirm)' 

      GOTO QUIT
   END

   --(Wan02) -- START
   SET @c_Facility = ''
   SELECT @c_Facility = Facility
   FROM ORDERS WITH (NOLOCK) 
   WHERE Orderkey = @c_Orderkey
   
   SET @c_EPACKNoRVPackIfOrdInMBOL = ''
   EXEC nspGetRight      
         @c_Facility  = @c_Facility      
      ,  @c_StorerKey = @c_StorerKey      
      ,  @c_sku       = NULL      
      ,  @c_ConfigKey = 'EPACKNoRVPackIfOrdInMBOL'      
      ,  @b_Success   = @b_Success                    OUTPUT      
      ,  @c_authority = @c_EPACKNoRVPackIfOrdInMBOL   OUTPUT      
      ,  @n_err       = @n_err                        OUTPUT      
      ,  @c_errmsg    = @c_errmsg                     OUTPUT
     
   IF @c_EPACKNoRVPackIfOrdInMBOL = '1' 
   BEGIN
      IF EXISTS ( SELECT 1 FROM MBOLDETAIL WITH (NOLOCK)
                  WHERE Orderkey = @c_Orderkey
                )
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60015 
         SET @c_errmsg='NSQL '+CONVERT(char(5),@n_err)
                      +': Pack Order populate to MBOL. Undo Pack Confirm Abort (isp_Ecom_UndoPackConfirm)' 

         GOTO QUIT         
      END    
   END          
   --(Wan02) - END

   BEGIN TRAN

   EXEC  isp_UnpackReversal
         @c_PickSlipNo  = @c_PickSlipNo
      ,  @c_UnpackType  = 'R'
      ,  @b_Success     = @b_Success   OUTPUT 
      ,  @n_err         = @n_err       OUTPUT 
      ,  @c_errmsg      = @c_errmsg    OUTPUT

   IF @b_Success <> 1
   BEGIN
      SET @n_continue = 3                                                                                              
      SET @n_err = 60020                                                                                              
      SET @c_errmsg='NSQL '+ CONVERT(CHAR(5),@n_err)+': Error Executing isp_UnpackReversal. (isp_Ecom_UndoPackConfirm)' 
                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ).'                                  
                                                                                                                       
      GOTO QUIT        
   END 

   --(Wan01) - START
   DECLARE CUR_PTD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRef 
   FROM PACKTASKDETAIL WITH (NOLOCK)
   WHERE TaskBatchNo = @c_TaskBatchNo
   AND   Orderkey = @c_Orderkey

   OPEN CUR_PTD
   
   FETCH NEXT FROM CUR_PTD INTO @n_RowRef
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      UPDATE PACKTASKDETAIL WITH (ROWLOCK)
      SET Status     = '3'
         ,EditWho    = SUSER_NAME()
         ,EditDate   = GETDATE()
         ,TrafficCop = NULL
      WHERE RowRef = @n_RowRef 

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60030  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PACKTASKDETAIL Table. (isp_Ecom_UndoPackConfirm)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         GOTO QUIT
      END

      FETCH NEXT FROM CUR_PTD INTO @n_RowRef
   END 
   CLOSE CUR_PTD
   DEALLOCATE CUR_PTD 
   --(Wan01) - END
QUIT:
   --(Wan01) - START
   IF CURSOR_STATUS( 'LOCAL', 'CUR_PTD') in (0 , 1)  
   BEGIN
      CLOSE CUR_PTD
      DEALLOCATE CUR_PTD
   END
   --(Wan01) - END
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_Ecom_UndoPackConfirm'
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