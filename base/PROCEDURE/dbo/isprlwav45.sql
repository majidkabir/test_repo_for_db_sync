SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: ispRLWAV45                                              */
/* Creation Date: 03-AUG-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  WMS-17585 - Adidas AU SCE trigger SO Export by wave release*/
/*        :                                                             */
/* Called By: ReleaseWave_SP                                            */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 17-JAN-2022  CSCHONG 1.0   Devops Scripts Combine                    */
/* 16-Aug-2023  WLChooi 1.1   WMS-23416 - Add Validation (WL01)         */
/************************************************************************/
CREATE   PROC [dbo].[ispRLWAV45]
   @c_wavekey NVARCHAR(10)
 , @b_Success INT           OUTPUT
 , @n_err     INT           OUTPUT
 , @c_errmsg  NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt INT
         , @n_Continue  INT
         , @n_RowRef    INT
         , @c_Orderkey  NVARCHAR(10)
         , @c_Storerkey NVARCHAR(15)
         , @c_Status    NVARCHAR(10)
         , @c_WaveType  NVARCHAR(20)   --WL01

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err = 0
   SET @c_errmsg = ''
   SET @c_Storerkey = N''

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

   SELECT TOP 1 @c_Storerkey = O.StorerKey
   FROM ORDERS O WITH (NOLOCK)
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON O.OrderKey = WD.OrderKey
   WHERE WD.WaveKey = @c_wavekey

   --WL01 S
   SELECT @c_WaveType = W.WaveType
   FROM WAVE W (NOLOCK)
   WHERE W.WaveKey = @c_wavekey

   IF EXISTS (  SELECT 1
                FROM WAVEDETAIL WD WITH (NOLOCK)
                JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = WD.OrderKey
                WHERE WD.WaveKey = @c_wavekey AND (OH.[Status] >= '5' OR OH.[Status] IN ( 'CANC', '0' )))
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_err = 63450
      SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Ship/Cancel orders found in Wave. (ispRLWAV45)'
      GOTO QUIT_SP
   END

   IF EXISTS (  SELECT 1
                FROM WAVEDETAIL WD WITH (NOLOCK)
                JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = WD.OrderKey
                LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.LISTNAME = 'ADISHPK' AND CL.Storerkey = OH.StorerKey
                                                   AND CL.Short = OH.ShipperKey
                WHERE WD.WaveKey = @c_wavekey AND (CL.Short IS NULL OR ISNULL(OH.Shipperkey,'') = '' ) )
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_err = 63455
      SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Invalid Carrier Name. (ispRLWAV45)'
      GOTO QUIT_SP
   END

   IF EXISTS (  SELECT 1
                FROM WAVEDETAIL WD WITH (NOLOCK)
                JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = WD.OrderKey
                JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey = OH.OrderKey
                JOIN LOC L WITH (NOLOCK) ON L.Loc = PD.Loc
                WHERE WD.WaveKey = @c_wavekey AND L.PutawayZone NOT LIKE '%WES%' )
   BEGIN
      IF EXISTS ( SELECT 1
                  FROM WAVEDETAIL WD WITH (NOLOCK)
                  JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = WD.OrderKey
                  LEFT JOIN PICKHEADER PH WITH (NOLOCK) ON OH.OrderKey = PH.OrderKey
                  WHERE WD.WaveKey = @c_wavekey AND PH.PickHeaderKey IS NULL )
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_err = 63460
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Please Print Picking Slip for VNA Orders. (ispRLWAV45)'
         GOTO QUIT_SP
      END

      IF @c_WaveType <> 'ADIHALFVNA'
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_err = 63465
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': VNA detected, please confirm wavetype. (ispRLWAV45)'
         GOTO QUIT_SP
      END
   END

   IF EXISTS (  SELECT TOP 1 1
                FROM WAVEDETAIL WD (NOLOCK)
                JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey
                JOIN ORDERDETAIL OD (NOLOCK) ON O.OrderKey = OD.OrderKey
                WHERE OD.OriginalQty > OD.QtyAllocated
                AND WD.Wavekey = @c_wavekey) AND @c_WaveType <> 'ADISHORTWAVE'
   BEGIN
      IF EXISTS ( SELECT 1
                  FROM dbo.StorerConfig SC (NOLOCK)
                  WHERE SC.StorerKey = @c_Storerkey
                  AND SC.ConfigKey = 'ReleaseWaveConfirmShort'
                  AND SC.SValue = '1' )
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_err = 63470
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Short detected, please confirm wavetype. (ispRLWAV45)'
         GOTO QUIT_SP
      END
   END
   --WL01 E

   EXEC ispGenTransmitLog2 @c_TableName = 'WSSOALCLOGAVB'
                         , @c_Key1 = @c_wavekey
                         , @c_Key2 = ''
                         , @c_Key3 = @c_Storerkey
                         , @c_TransmitBatch = ''
                         , @b_Success = @b_Success OUTPUT
                         , @n_err = @n_err OUTPUT
                         , @c_errmsg = @c_errmsg OUTPUT

   IF @b_Success <> 1
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END
   ELSE --WL01 S
   BEGIN
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT OH.OrderKey
      FROM WAVEDETAIL WD WITH (NOLOCK)
      JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      WHERE WD.WaveKey = @c_wavekey AND OH.[Status] IN ( '1', '2' )

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP
      INTO @c_Orderkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE ORDERS WITH (ROWLOCK)
         SET [Status] = '3'
         WHERE OrderKey = @c_Orderkey

         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @n_err = 63455
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Update ORDERS Failed! (ispRLWAV45)'
            GOTO QUIT_SP
         END

         FETCH NEXT FROM CUR_LOOP
         INTO @c_Orderkey
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END
   --WL01 E

   --FETCH NEXT FROM CUR_ORD INTO @c_Orderkey, @c_Storerkey
   --END       
   --CLOSE CUR_ORD  
   --DEALLOCATE CUR_ORD  


   QUIT_SP:

   IF CURSOR_STATUS('LOCAL', 'CUR_ORD') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_ORD
      DEALLOCATE CUR_ORD
   END

   --WL01 S
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END
   --WL01 E

   IF @n_Continue = 3 -- Error Occured - Process And Return  
   BEGIN
      SET @b_Success = 0
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRLWAV45'
      RAISERROR(@c_errmsg, 16, 1) WITH SETERROR -- SQL2012  
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