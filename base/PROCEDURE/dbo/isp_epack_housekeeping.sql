SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_EPACK_HouseKeeping                                  */
/* Creation Date: 20-OCT-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:                                                             */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_EPACK_HouseKeeping] 
AS 
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         ,  @b_Success        INT 
         ,  @n_err            INT  
         ,  @c_errmsg         NVARCHAR(215) 

         , @c_TaskBatchNo     NVARCHAR(10)
         , @c_PickSlipNo      NVARCHAR(10)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   DECLARE CUR_HSEKP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT TaskBatchNo
   FROM   PACKHEADER WITH (NOLOCK)
   WHERE  TaskBatchNo <> ''
   AND    Status < '9'
      
   OPEN CUR_HSEKP
   
   FETCH NEXT FROM CUR_HSEKP INTO @c_TaskBatchNo
   WHILE @@FETCH_STATUS <> -1
   BEGIN
   IF EXISTS( SELECT 1
              FROM PACKTASK WITH (NOLOCK) 
              WHERE TaskBatchNo = @c_TaskBatchNo
             )
      BEGIN
         GOTO NEXT_REC
      END

      DECLARE CUR_DELPS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickSlipNo
      FROM   PACKHEADER WITH (NOLOCK)
      WHERE  TaskBatchNo = @c_TaskBatchNo
      AND    Status < '9'
      
      OPEN CUR_DELPS
   
      FETCH NEXT FROM CUR_DELPS INTO @c_PickSlipNo
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @n_continue = 1

         BEGIN TRAN

         IF EXISTS ( SELECT 1
                     FROM PACKDETAIL WITH (NOLOCK)
                     WHERE PickSlipNo = @c_PickSlipNo
                    )
         BEGIN
            DELETE PACKDETAIL 
            WHERE PickSlipNo = @c_PickSlipNo

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 60010  
               SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Error DELETE into PACKDETAIL Table. (isp_EPACK_HouseKeeping)' 
                            + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            END
         END

         DELETE PACKHEADER
         WHERE PickSlipNo = @c_PickSlipNo

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60020  
            SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Error DELETE into PACKHEADER Table. (isp_EPACK_HouseKeeping)' 
                         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 

         END

         IF @n_continue = 3 
         BEGIN
            ROLLBACK TRAN
         END
         ELSE
         BEGIN
            COMMIT TRAN
         END 

         FETCH NEXT FROM CUR_DELPS INTO @c_PickSlipNo
      END
      CLOSE CUR_DELPS
      DEALLOCATE CUR_DELPS
                    
      NEXT_REC:
      FETCH NEXT FROM CUR_HSEKP INTO @c_TaskBatchNo
   END
   CLOSE CUR_HSEKP
   DEALLOCATE CUR_HSEKP 

QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_HSEKP') IN (0 , 1)  
   BEGIN
      CLOSE CUR_HSEKP
      DEALLOCATE CUR_HSEKP
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_DELPS') IN (0 , 1)  
   BEGIN
      CLOSE CUR_DELPS
      DEALLOCATE CUR_DELPS
   END
   
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO