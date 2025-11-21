SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispLPRLPRO02                                                     */
/* Creation Date: 07-Jul-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20156 - [CN] IKEA AMR Robot Add New RCM & SP For        */ 
/*          Triggering Order Release                                    */
/*                                                                      */
/* Usage:   Storerconfig LoadReleaseToProcess_SP = ispLPRLPRO?? to      */
/*          enable release Load to process option                       */
/*                                                                      */
/* Called By: isp_LoadReleaseToProcess_Wrapper                          */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 07-Jul-2022  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/

CREATE   PROC [dbo].[ispLPRLPRO02] 
   @c_Loadkey  NVARCHAR(10),
   @c_CallFrom NVARCHAR(50),    --BuildLoad / ManualLoad
   @b_Success  INT OUTPUT,
   @n_err      INT OUTPUT,
   @c_errmsg   NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue        INT
         , @b_debug           INT
         , @n_StartTranCnt    INT
         , @c_Storerkey       NVARCHAR(15)
         , @c_TableName       NVARCHAR(15)
         , @c_Orderkey        NVARCHAR(10)
         , @c_PickslipNo      NVARCHAR(10)
         , @c_Facility        NVARCHAR(5)
         , @c_OrderStatus     NVARCHAR(1)
         , @c_DocType         NVARCHAR(1)
         , @c_trmlogkey       NVARCHAR(10)
         , @c_TransmitBatch   NVARCHAR(50) = ''
         , @dt_TLDateTime     DATETIME
         , @c_MinValue        NVARCHAR(50) = ''
         , @c_MaxValue        NVARCHAR(50) = ''
         , @c_GenMethod       NVARCHAR(30) = ''
         , @c_Key2            NVARCHAR(10) = ''
         , @c_Authority             NVARCHAR(50)

   SELECT @c_Storerkey  = OH.Storerkey
        , @c_Facility   = OH.Facility
   FROM LOADPLANDETAIL LPD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
   WHERE LPD.LoadKey = @c_Loadkey

   IF @n_err = 1
      SET @b_debug = 1
      
   SELECT @n_StartTranCnt = @@TRANCOUNT, @n_continue = 1, @b_success = 1, @n_err = 0, @c_errmsg = ''

   ------Validation--------
   IF @n_continue=1 or @n_continue=2  
   BEGIN
      SELECT @c_Authority = SC.sValue
      FROM StorerConfig SC (NOLOCK)
      WHERE SC.StorerKey = @c_Storerkey
      AND SC.Facility = @c_Facility
      AND SC.ConfigKey = 'GenAPIToAMR'

      IF ISNULL(@c_Authority,'') IN ('', '0')
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': API to AMR is denied. (ispLPRLPRO02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO RETURN_SP
      END

      IF @c_OrderStatus < '1'
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release Failed. Some of the orders are not fully allocated. (ispLPRLPRO02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO RETURN_SP
      END  

      --Not allow mixing Single and Multi Order
      SET @c_MinValue = ''
      SET @c_MaxValue = ''

      SELECT @c_MinValue = MIN(OH.OrderKey)
      FROM LOADPLANDETAIL LPD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
      WHERE LPD.LoadKey = @c_Loadkey
      AND OH.OpenQty = 1

      SELECT @c_MaxValue = MIN(OH.OrderKey)
      FROM LOADPLANDETAIL LPD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
      WHERE LPD.LoadKey = @c_Loadkey
      AND OH.OpenQty > 1

      IF ISNULL(@c_MinValue,'') <> '' AND ISNULL(@c_MaxValue,'') <> ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release Failed. Not allow mixing Single and Multi Order. (ispLPRLPRO02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO RETURN_SP
      END

      --Not allow mixing ECOM Order
      SET @c_MinValue = ''
      SET @c_MaxValue = ''

      SELECT @c_MinValue = MIN(OH.DocType)
           , @c_MaxValue = MAX(OH.DocType)
      FROM LOADPLANDETAIL LPD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
      WHERE LPD.LoadKey = @c_Loadkey

      IF @c_MinValue <> @c_MaxValue
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release Failed. Not allow mixing ECOM order. (ispLPRLPRO02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO RETURN_SP
      END
   END

   ------Initializing Data-------   
   IF (@n_continue = 1 or @n_continue = 2)
   BEGIN
      CREATE TABLE #TMP_ORD (
         RowID          INT NOT NULL IDENTITY(1,1) PRIMARY KEY
       , Orderkey       NVARCHAR(10)
       , GenMethod      NVARCHAR(20)
       , Tablename      NVARCHAR(30)
      )

      CREATE TABLE #TMP_TL2 (
         RowID          INT NOT NULL IDENTITY(1,1) PRIMARY KEY 
       , Tablename      NVARCHAR(30)
       , Key1           NVARCHAR(10)
       , Key2           NVARCHAR(30)
       , Key3           NVARCHAR(20)
      )

      ;WITH CLKUP AS (
         SELECT DISTINCT CL.Short, CL.Long, CL.Code
                       , CL.UDF01, CL.UDF02, CL.UDF03
         FROM CODELKUP CL (NOLOCK)
         WHERE CL.LISTNAME = 'AMRORDTYPE'
         AND CL.Storerkey = @c_Storerkey
         AND CL.code2 = @c_Facility
      ),
      ORD1 AS (
         SELECT DISTINCT OH.Orderkey, CLKUP.Short, CLKUP.Long
         FROM LOADPLANDETAIL LPD (NOLOCK)
         JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
         JOIN CLKUP CLKUP ON CLKUP.UDF01 = OH.DocType 
                         AND CLKUP.UDF02 = OH.ShipperKey
                         AND CLKUP.UDF03 = OH.ECOM_SINGLE_Flag
         WHERE LPD.LoadKey = @c_Loadkey
      ),
      ORD2 AS (
         SELECT DISTINCT OH.Orderkey, CLKUP.Short, CLKUP.Long
         FROM LOADPLANDETAIL LPD (NOLOCK)
         JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
         JOIN CLKUP CLKUP ON CLKUP.UDF01 = OH.DocType 
                         AND CLKUP.UDF02 = '*'
                         AND CLKUP.UDF03 = OH.ECOM_SINGLE_Flag
         WHERE LPD.LoadKey = @c_Loadkey
         AND OH.OrderKey NOT IN (SELECT DISTINCT ORD1.OrderKey
                                 FROM ORD1 ORD1)
      )
      INSERT INTO #TMP_ORD (Orderkey, GenMethod, Tablename)
      SELECT ORD1.OrderKey, ORD1.Short, ORD1.Long
      FROM ORD1
      UNION ALL
      SELECT ORD2.OrderKey, ORD2.Short, ORD2.Long
      FROM ORD2
      ORDER BY OrderKey

      IF NOT EXISTS (SELECT 1 FROM #TMP_ORD)
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Order Type is different to Codelkup. (ispLPRLPRO02)' 
                          + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         GOTO RETURN_SP 
      END
   END

   ------Insert Into Transmitlog2-------
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TOR.Orderkey, TOR.GenMethod, TOR.Tablename
      FROM #TMP_ORD TOR
      ORDER BY TOR.RowID

      OPEN CUR_ORD
      
      FETCH NEXT FROM CUR_ORD INTO @c_Orderkey, @c_GenMethod, @c_TableName
      
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @c_Key2 = ''

         IF @c_GenMethod = 'BATCH'
         BEGIN
            SELECT TOP 1 @c_Key2 = PD.PickSlipNo
            FROM PICKDETAIL PD (NOLOCK)
            WHERE PD.OrderKey = @c_Orderkey
         END
         ELSE IF @c_GenMethod = 'LOAD'
         BEGIN
            SET @c_Key2 = @c_Loadkey
         END

         INSERT INTO #TMP_TL2 (Tablename, Key1, Key2, Key3)
         SELECT @c_TableName, @c_Orderkey, @c_Key2, @c_Storerkey

         NEXT_LOOP:
         FETCH NEXT FROM CUR_ORD INTO @c_Orderkey, @c_GenMethod, @c_TableName
      END
      CLOSE CUR_ORD
      DEALLOCATE CUR_ORD
   END

   IF EXISTS (SELECT 1 
              FROM TRANSMITLOG2 TL2 (NOLOCK)
              JOIN #TMP_TL2 TT (NOLOCK) ON TT.Tablename = TL2.tablename
                                       AND TT.Key1 = TL2.key1
                                       AND TT.Key2 = TL2.key2
                                       AND TT.Key3 = TL2.key3)
   BEGIN
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ' + @c_Loadkey + ' has generated Transmitlog2 record to AMR. (ispLPRLPRO02)' 
                       + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      GOTO RETURN_SP 
   END
   ELSE   --Insert Transmitlog2
   BEGIN
      DECLARE CUR_TL2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TT.Key1, TT.Key2, TT.Tablename
      FROM #TMP_TL2 TT
      ORDER BY TT.RowID

      OPEN CUR_TL2
      
      FETCH NEXT FROM CUR_TL2 INTO @c_Orderkey, @c_Key2, @c_TableName
      
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SELECT @b_success = 1
         EXECUTE nspg_getkey
         'TransmitlogKey2'
         , 10
         , @c_trmlogkey OUTPUT
         , @b_success   OUTPUT
         , @n_err       OUTPUT
         , @c_errmsg    OUTPUT
         
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) 
                             + ': Unable to Obtain transmitlogkey. (ispLPRLPRO02) ( SQLSvr MESSAGE=' 
                             + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            GOTO RETURN_SP 
         END
         ELSE 
         BEGIN
            IF (@n_continue = 1 OR @n_continue = 2)
            BEGIN
               INSERT INTO Transmitlog2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)
               VALUES (@c_trmlogkey, @c_TableName, @c_Orderkey, @c_Key2, @c_Storerkey, '0', @c_TransmitBatch)
         
               SELECT @n_err = @@ERROR
         
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68035   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert into TRANSMITLOG2 Failed. (ispLPRLPRO02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                  GOTO RETURN_SP 
               END
            END
         END

         NEXT_LOOP_TL2:
         FETCH NEXT FROM CUR_TL2 INTO @c_Orderkey, @c_Key2, @c_TableName
      END
      CLOSE CUR_TL2
      DEALLOCATE CUR_TL2
      
      UPDATE dbo.LoadPlan
      SET LoadPickMethod   = 'AMR'
        , TrafficCop       = NULL
        , EditDate         = GETDATE()
        , EditWho          = SUSER_SNAME()
      WHERE LoadKey = @c_Loadkey
     
      IF @@ERROR <> 0 
      BEGIN
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE Loadplan Failed. (ispLPRLPRO02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
          GOTO RETURN_SP 
      END
   END  

RETURN_SP:
   IF ISNULL(@c_errmsg,'') = ''
   BEGIN
      SET @c_errmsg = 'AMR record generated successfully.'
   END

   IF (SELECT CURSOR_STATUS('LOCAL','CUR_ORD')) >=0 
   BEGIN
      CLOSE CUR_ORD           
      DEALLOCATE CUR_ORD      
   END  

   IF (SELECT CURSOR_STATUS('LOCAL','CUR_TL2')) >=0 
   BEGIN
      CLOSE CUR_TL2           
      DEALLOCATE CUR_TL2      
   END  

   IF OBJECT_ID('tempdb..#TMP_ORD') IS NOT NULL
   BEGIN
      DROP TABLE #TMP_ORD
   END

   IF OBJECT_ID('tempdb..#TMP_TL2') IS NOT NULL
   BEGIN
      DROP TABLE #TMP_TL2
   END

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCnt
         BEGIN
            COMMIT TRAN
         END
      END
      execute nsp_logerror @n_err, @c_errmsg, 'ispLPRLPRO02'
      --RAISERROR @n_err @c_errmsg
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO