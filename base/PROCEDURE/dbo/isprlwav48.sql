SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: ispRLWAV48                                              */
/* Creation Date: 19-JAN-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  WMS-18759 - Mosaic AU SCE trigger SO Export by wave release*/
/*        :                                                             */
/* Called By: ReleaseWave_SP                                            */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 19-JAN-2022  CSCHONG 1.0   Devops Scripts Combine                    */
/* 03-MAY-2022  SYCHUA  1.1   JSM-65563 Check whether exist for         */
/*                            Pickheader orderkey (SY01)                */
/************************************************************************/
CREATE PROC [dbo].[ispRLWAV48]
        @c_wavekey      NVARCHAR(10)
       ,@b_Success      INT            OUTPUT
       ,@n_err          INT            OUTPUT
       ,@c_errmsg       NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
           @n_StartTCnt       INT
         , @n_Continue        INT
         , @n_RowRef          INT
         , @c_Orderkey        NVARCHAR(10)
         , @c_Storerkey       NVARCHAR(15)
         , @c_Status          NVARCHAR(10)
         , @c_TBLName         NVARCHAR(30) = ''

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   SET @c_Storerkey = ''

       SELECT TOP 1 @c_Storerkey = O.storerkey
       FROM ORDERS O WITH (NOLOCK)
       JOIN WAVEDETAIL WD WITH (NOLOCK) ON O.Orderkey = WD.Orderkey
       WHERE WD.Wavekey = @c_Wavekey
       -----Wave Validation-----
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF NOT EXISTS (SELECT 1
                   FROM wave w(nolock)
                    join orders o (nolock) on o.userdefine09=w.wavekey
                    JOIN pickdetail pd (nolock) on pd.orderkey=o.orderkey
                    WHERE o.storerkey=@c_Storerkey AND w.WaveKey = @c_wavekey
                    GROUP by w.wavekey HAVING min(pd.status)>='4' --and Max(pd.status) ='9'

                   ) OR NOT EXISTS (SELECT 1 FROM PICKHEADER PH(nolock)
                                    join orders o (nolock) on o.userdefine09=PH.wavekey
                                    JOIN pickdetail pd (nolock) on pd.orderkey=o.orderkey
                                    WHERE o.storerkey=@c_Storerkey AND PH.WaveKey =  @c_wavekey)
                     --SY01 START
                     OR EXISTS (SELECT 1 FROM orders o (nolock)
                                JOIN pickdetail pd (nolock) on pd.orderkey=o.orderkey
                                LEFT join PICKHEADER PH(nolock) on o.orderkey=PH.orderkey
                                WHERE o.storerkey=@c_Storerkey AND o.userdefine09 =  @c_wavekey
                                AND PH.pickheaderkey IS NULL)
                     --SY01 END
        BEGIN
          SELECT @n_continue = 3
          SELECT @n_err = 83070
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Wave not ready to be released, please check wave status. (ispRLWAV48)'
        END
    END

   --DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   --   SELECT O.Orderkey, O.Storerkey
   --   FROM ORDERS O WITH (NOLOCK)
   --   JOIN WAVEDETAIL WD WITH (NOLOCK) ON O.Orderkey = WD.Orderkey
   --   WHERE WD.Wavekey = @c_Wavekey
   --   ORDER BY O.Orderkey

   --OPEN CUR_ORD

   --FETCH NEXT FROM CUR_ORD INTO @c_Orderkey, @c_Storerkey

   --WHILE @@FETCH_STATUS <> -1

   --BEGIN
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN


      EXEC ispGenTransmitlog2
         @c_TableName = 'WSSCEWAVE'
        ,@c_Key1 = @c_Wavekey
        ,@c_Key2 = ''
        ,@c_Key3 = @c_Storerkey
        ,@c_TransmitBatch = ''
        ,@b_Success = @b_success OUTPUT
        ,@n_err = @n_err OUTPUT
        ,@c_errmsg = @c_errmsg OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
         GOTO QUIT_SP
      END

  END
   --FETCH NEXT FROM CUR_ORD INTO @c_Orderkey, @c_Storerkey
   --END
   --CLOSE CUR_ORD
   --DEALLOCATE CUR_ORD


QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_ORD') in (0 , 1)
   BEGIN
      CLOSE CUR_ORD
      DEALLOCATE CUR_ORD
   END

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRLWAV48'
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