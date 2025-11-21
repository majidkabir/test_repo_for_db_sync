SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispPKD06                                           */
/* Creation Date: 13-Dec-2022                                           */
/* Copyright: LFL                                                       */
/* Written by:ChongCS                                                   */
/*                                                                      */
/* Purpose: WMS-21313 -[CN] YONEX time note of UCC status change        */
/*                                                                      */
/* Called By: isp_PickDetailTrigger_Wrapper from Pickdetail Trigger     */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 13-Dec-2022  ChongCS  1.0   DevOps Combine Script                    */
/* 11-Jan-2022  WLChooi  1.1   WMS-21531 - Add new logic (WL01)         */
/************************************************************************/

CREATE   PROC [dbo].[ispPKD06]
   @c_Action    NVARCHAR(10)
 , @c_Storerkey NVARCHAR(15)
 , @b_Success   INT           OUTPUT
 , @n_Err       INT           OUTPUT
 , @c_ErrMsg    NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue     INT
         , @n_StartTCnt    INT
         , @c_Containerkey NVARCHAR(10)
         , @c_Dropid       NVARCHAR(30)


   SELECT @n_Continue = 1
        , @n_StartTCnt = @@TRANCOUNT
        , @n_Err = 0
        , @c_ErrMsg = ''
        , @b_Success = 1

   IF @c_Action NOT IN ( 'INSERT', 'UPDATE', 'DELETE' )
      GOTO QUIT_SP

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END

   IF @c_Action = 'DELETE'
   BEGIN
      --Retrieve deleted whole pallet exist in container
      DECLARE CUR_ID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT D.DropID
      FROM #DELETED D
      -- JOIN ORDERS O (NOLOCK) ON D.Orderkey = O.Orderkey
      JOIN PackHeader PH (NOLOCK) ON D.PickSlipNo = PH.PickSlipNo
      -- JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno
      -- JOIN UCC (NOLOCK) ON UCC.uccno = PD.DropID
      WHERE D.StorerKey = @c_Storerkey AND ISNULL(D.DropID, '') <> ''
      ORDER BY D.DropID

      OPEN CUR_ID

      FETCH NEXT FROM CUR_ID
      INTO @c_Dropid

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF EXISTS (  SELECT 1
                      FROM UCC (NOLOCK)
                      WHERE UCCNo = @c_Dropid AND Storerkey = @c_Storerkey AND [Status] = '6')
         BEGIN

            UPDATE dbo.UCC
            SET [Status] = '3'
              , TrafficCop = NULL
              , EditWho = SUSER_SNAME()
              , EditDate = GETDATE()
            WHERE UCCNo = @c_Dropid AND Storerkey = @c_Storerkey


            SET @n_Err = @@ERROR

            IF @n_Err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @n_Err = 35100
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5), @n_Err) + ': Update  UCC Failed. (ispPKD06)'
            END
         END
         FETCH NEXT FROM CUR_ID
         INTO @c_Dropid
      END
      CLOSE CUR_ID
      DEALLOCATE CUR_ID

      --WL01 S
      IF @n_Continue = 1 OR @n_Continue = 2
      BEGIN
         UPDATE SerialNo WITH (ROWLOCK)
         SET SerialNo.PickSlipNo = ''
           , SerialNo.CartonNo = 0
           , SerialNo.LabelLine = ''
           , SerialNo.OrderLineNumber = ''
           , SerialNo.OrderKey = ''
           , SerialNo.Status = '1'
         FROM SerialNo
         JOIN PackHeader PH (NOLOCK) ON SerialNo.OrderKey = PH.OrderKey
         JOIN #DELETED D ON  D.PickSlipNo = PH.PickSlipNo
                         AND SerialNo.StorerKey = D.StorerKey
                         AND SerialNo.SKU = D.SKU
                         AND SerialNo.CartonNo = D.CartonNo
                         AND SerialNo.UserDefine01 = D.DropID
         WHERE D.StorerKey = @c_Storerkey AND ISNULL(D.DropId, '') <> ''

         SET @n_Err = @@ERROR

         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 35105 -- Should Be Set To The SQL Errmessage but I don't know how to do so. 
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Delete Failed On Table PACKDETAIL. (ispPKD06)'

            GOTO QUIT_SP
         END

         --delete pack by sku 	
         UPDATE SerialNo WITH (ROWLOCK)
         SET SerialNo.PickSlipNo = ''
           , SerialNo.CartonNo = 0
           , SerialNo.LabelLine = ''
           , SerialNo.OrderLineNumber = ''
           , SerialNo.OrderKey = ''
           , SerialNo.Status = '1'
         FROM SerialNo
         JOIN PackHeader PH (NOLOCK) ON SerialNo.OrderKey = PH.OrderKey
         JOIN #DELETED D ON  D.PickSlipNo = PH.PickSlipNo
                         AND SerialNo.StorerKey = D.StorerKey
                         AND SerialNo.SKU = D.SKU
                         AND CAST(SerialNo.OrderLineNumber AS INT) = D.CartonNo
         WHERE D.StorerKey = @c_Storerkey AND ISNULL(D.DropId, '') = ''

         SET @n_Err = @@ERROR

         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 35110 -- Should Be Set To The SQL Errmessage but I don't know how to do so. 
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Delete Failed On Table PACKDETAIL. (ispPKD06)'

            GOTO QUIT_SP
         END
      END
   --WL01 E
   END

   QUIT_SP:

   IF @n_Continue = 3 -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE dbo.nsp_logerror @n_Err, @c_ErrMsg, 'ispPKD06'
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO