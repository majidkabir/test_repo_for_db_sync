SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_BackendPickTaskAutoSort                           */
/* Creation Date: 17-Sep-2021                                              */
/* Copyright: LFL                                                          */
/* Written by:  WLChooi                                                    */
/*                                                                         */
/* Purpose: WMS-17964 - [CN] MAST VS Add New Backend Job To Trigger        */
/*          Transmitlog2 of Completed Pick Tasks for Auto-Sorting Machines */
/*                                                                         */
/* Called By: SQL Job                                                      */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 17-Sep-2021  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/  
CREATE PROC [dbo].[isp_BackendPickTaskAutoSort]  
(     @c_Storerkey   NVARCHAR(15)
  ,   @c_Facility    NVARCHAR(5)   = ''
  ,   @b_Success     INT           = 1  OUTPUT
  ,   @n_Err         INT           = 0  OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) = '' OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug              INT = 0
         , @n_Continue           INT
         , @n_StartTCnt          INT 
   
   DECLARE @c_GetPickdetailkey   NVARCHAR(10)
         , @c_GetStorerkey       NVARCHAR(15)
         , @c_TLKey2             NVARCHAR(50)
         , @c_TableName          NVARCHAR(50)
         , @c_trmlogkey          NVARCHAR(10) = ''
         , @n_MaxRecPerTKey      INT = 0
         , @c_DocType            NVARCHAR(10)
         , @n_SeqNo              INT 

   IF @n_Err > 0
   BEGIN
      SET @b_Debug = @n_Err
   END
   
   --@b_Debug = 0 -> Insert transmitlog into temp table, update Pickdetail, insert actual Transmitlog2 table
   --@b_Debug = 1 -> Insert transmitlog into temp table, update Pickdetail, do not insert actual Transmitlog2 table
   --@b_Debug = 2 -> Insert transmitlog into temp table, do not update Pickdetail, do not insert actual Transmitlog2 table
          
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  

   IF @@TRANCOUNT = 0
      BEGIN TRAN
   
   IF NOT EXISTS (SELECT 1
                  FROM STORERCONFIG (NOLOCK)
                  WHERE Storerkey = @c_Storerkey
                  AND Configkey = 'CapturePickForSort'
                  AND SValue = '1')
   BEGIN
      GOTO QUIT_SP
   END

   CREATE TABLE #TMP_PICK (
         TLKey2          NVARCHAR(10)
       , DocType         NVARCHAR(1)
       , PickdetailKey   NVARCHAR(10)
       , MaxRecPerTKey   INT
       , TableName       NVARCHAR(50)
       , Storerkey       NVARCHAR(15)
       , TransmitLogKey  NVARCHAR(10) NULL
   )

   --For debugging use
   CREATE TABLE #TMP_TKEY (
         TLogKey     NVARCHAR(10)
       , TableName   NVARCHAR(50)
       , TKEY1       NVARCHAR(10)
       , TKEY2       NVARCHAR(10)
       , TKEY3       NVARCHAR(20)
   )

   --B2B
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      DECLARE CUR_B2B CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT PD.PickDetailKey, OH.LoadKey, PD.StorerKey
                       , CASE WHEN ISNUMERIC(CL2.UDF04) = 1 THEN CL2.UDF04 ELSE 1 END
         FROM PICKDETAIL PD (NOLOCK)
         JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PD.OrderKey
         JOIN LOC L (NOLOCK) ON L.Loc = PD.Loc
         JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'WSRCSBHCON' AND CL.Short = '1'
                                  AND CL.Long  = OH.Facility
                                  AND CL.UDF01 = OH.DocType
                                  AND CL.UDF02 = ISNULL(OH.ECOM_SINGLE_Flag,'')
                                  AND CL.UDF03 = PD.[Status]
         CROSS APPLY (SELECT MIN(CODELKUP.UDF04) AS UDF04
                      FROM CODELKUP (NOLOCK)
                      WHERE CODELKUP.LISTNAME = 'WSRCSBHCON' 
                      AND CODELKUP.Short = '1'
                      AND CODELKUP.Long  = OH.Facility
                      AND CODELKUP.UDF01 = OH.DocType) AS CL2
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.OrderKey = OH.OrderKey
         JOIN LOADPLAN LP (NOLOCK) ON LP.LoadKey = LPD.LoadKey
         WHERE OH.StorerKey = @c_Storerkey
         AND OH.Facility = CASE WHEN ISNULL(@c_Facility,'')  = '' THEN OH.Facility ELSE @c_Facility END
         AND OH.Doctype = 'N'
         AND LP.UserDefine05 = 'Minions'
         --AND PD.[Status] = '3'
         AND ISNULL(PD.CartonGroup,'') IN ('STD','')
         ORDER BY OH.LoadKey, PD.PickDetailKey
         
      OPEN CUR_B2B
         
      FETCH NEXT FROM CUR_B2B INTO @c_GetPickdetailkey, @c_TLKey2, @c_GetStorerkey, @n_MaxRecPerTKey
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF ISNULL(@c_TLKey2,'') = ''
            GOTO NEXT_B2B_REC

         INSERT INTO #TMP_PICK(TLKey2, DocType, PickdetailKey, MaxRecPerTKey, TableName, Storerkey)
         VALUES(@c_TLKey2
              , 'N'
              , @c_GetPickdetailkey
              , @n_MaxRecPerTKey
              , 'WSRCSBHB2B'
              , @c_GetStorerkey
            )

         NEXT_B2B_REC:
         FETCH NEXT FROM CUR_B2B INTO @c_GetPickdetailkey, @c_TLKey2, @c_GetStorerkey, @n_MaxRecPerTKey
      END
      CLOSE CUR_B2B
      DEALLOCATE CUR_B2B
   END

   --B2C
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      DECLARE CUR_B2C CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT PD.PickDetailKey, PD.PickSlipNo, PD.Storerkey
                       , CASE WHEN ISNUMERIC(CL2.UDF04) = 1 THEN CL2.UDF04 ELSE 1 END
         FROM PICKDETAIL PD (NOLOCK)
         JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PD.OrderKey
         JOIN LOC L (NOLOCK) ON L.Loc = PD.Loc
         JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'WSRCSBHCON' AND CL.Short = '1'
                                  AND CL.Long  = OH.Facility
                                  AND CL.UDF01 = OH.DocType
                                  AND CL.UDF02 = ISNULL(OH.ECOM_SINGLE_Flag,'')
                                  AND CL.UDF03 = PD.[Status]
         CROSS APPLY (SELECT MIN(CODELKUP.UDF04) AS UDF04
                      FROM CODELKUP (NOLOCK)
                      WHERE CODELKUP.LISTNAME = 'WSRCSBHCON' 
                      AND CODELKUP.Short = '1'
                      AND CODELKUP.Long  = OH.Facility
                      AND CODELKUP.UDF01 = OH.DocType) AS CL2
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.OrderKey = OH.OrderKey
         JOIN LOADPLAN LP (NOLOCK) ON LP.LoadKey = LPD.LoadKey
         WHERE OH.StorerKey = @c_Storerkey
         AND OH.Facility = CASE WHEN ISNULL(@c_Facility,'')  = '' THEN OH.Facility ELSE @c_Facility END
         AND OH.Doctype = 'E'
         AND LP.UserDefine05 = 'Minions'
         --AND PD.[Status] = '3'
         AND ISNULL(PD.CartonGroup,'') IN ('STD','')
         ORDER BY PD.Pickslipno, PD.PickDetailKey

      OPEN CUR_B2C
         
      FETCH NEXT FROM CUR_B2C INTO @c_GetPickdetailkey, @c_TLKey2, @c_GetStorerkey, @n_MaxRecPerTKey
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF ISNULL(@c_TLKey2,'') = ''
            GOTO NEXT_B2C_REC

         INSERT INTO #TMP_PICK(TLKey2, DocType, PickdetailKey, MaxRecPerTKey, TableName, Storerkey)
         VALUES(@c_TLKey2
              , 'E'
              , @c_GetPickdetailkey
              , @n_MaxRecPerTKey
              , 'WSRCSBHB2C'
              , @c_GetStorerkey
            )

         NEXT_B2C_REC:
         FETCH NEXT FROM CUR_B2C INTO @c_GetPickdetailkey, @c_TLKey2, @c_GetStorerkey, @n_MaxRecPerTKey
      END
      CLOSE CUR_B2C
      DEALLOCATE CUR_B2C
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      WITH CTE AS ( SELECT TLKey2, PickdetailKey, DocType
                          , (Row_Number() OVER (PARTITION BY TLKey2 ORDER BY PickdetailKey) - 1 ) / MaxRecPerTKey + 1 AS SeqNo
                          , TableName
                          , Storerkey
                          , MaxRecPerTKey
                    FROM #TMP_PICK)
      SELECT CTE.TLKey2, CTE.DocType, COUNT(DISTINCT CTE.SeqNo), CTE.TableName, CTE.Storerkey, CTE.MaxRecPerTKey
      FROM CTE
      GROUP BY CTE.TLKey2, CTE.DocType, CTE.TableName, CTE.Storerkey, CTE.MaxRecPerTKey
      ORDER BY CTE.TableName, CTE.TLKey2
      
      OPEN CUR_LOOP
      
      FETCH NEXT FROM CUR_LOOP INTO @c_TLKey2, @c_DocType, @n_SeqNo, @c_TableName, @c_GetStorerkey, @n_MaxRecPerTKey
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         WHILE @n_SeqNo > 0
         BEGIN
            SELECT @b_success = 1
            
            IF @n_Continue = 1 OR @n_Continue = 2
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
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63820   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) 
                                   + ': Unable to Obtain transmitlogkey. (isp_BackendPickTaskAutoSort) ( SQLSvr MESSAGE=' 
                                   + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
               ELSE 
               BEGIN
                  IF @b_Debug = 0
                  BEGIN
                     --Insert temp table first
                     INSERT INTO #TMP_TKEY(TLogKey, TableName, TKEY1, TKEY2, TKEY3)
                     VALUES(@c_trmlogkey 
                          , @c_TableName 
                          , @c_trmlogkey 
                          , @c_TLKey2
                          , @c_GetStorerkey
                     )
                  END
               END
            END
      
            SET @n_SeqNo = @n_SeqNo - 1
      
            --Update Transmitlogkey back to #TMP_PICK
            ;WITH CTE AS ( SELECT TOP (@n_MaxRecPerTKey) TP.PickdetailKey
                           FROM #TMP_PICK TP
                           WHERE TP.TLKey2 = @c_TLKey2
                           AND TP.DocType = @c_DocType
                           AND TP.TableName = @c_TableName
                           AND TP.Storerkey = @c_GetStorerkey
                           AND ISNULL(TP.TransmitLogKey,'') = ''
                           ORDER BY TP.PickdetailKey ASC)
            UPDATE #TMP_PICK
            SET #TMP_PICK.TransmitLogKey = @c_trmlogkey
            FROM CTE
            JOIN #TMP_PICK TP ON TP.PickdetailKey = CTE.PickdetailKey
         END
      
         FETCH NEXT FROM CUR_LOOP INTO @c_TLKey2, @c_DocType, @n_SeqNo, @c_TableName, @c_GetStorerkey, @n_MaxRecPerTKey
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

   IF @b_Debug IN (1,2)
      SELECT * FROM #TMP_PICK ORDER BY TableName, TLKey2

   IF (@n_Continue = 1 OR @n_Continue = 2) AND @b_Debug IN (0,1)
   BEGIN
      --Update Pickdetail.CartonGroup
      DECLARE CUR_PD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT TP.Pickdetailkey, TP.TransmitLogKey
      FROM #TMP_PICK TP
      WHERE ISNULL(TP.TransmitLogKey,'') <> ''
      ORDER BY TP.Pickdetailkey, TP.TransmitLogKey
       
      OPEN CUR_PD
      
      FETCH NEXT FROM CUR_PD INTO @c_GetPickdetailkey, @c_trmlogkey
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE dbo.PICKDETAIL
         SET CartonGroup = @c_trmlogkey
           , TrafficCop  = NULL
           , EditDate    = GETDATE()
           , EditWho     = SUSER_SNAME()
         WHERE PickDetailKey = @c_GetPickdetailkey
         
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63825   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) 
                             + ': Unable to UPDATE Pickdetail table. (isp_BackendPickTaskAutoSort) ( SQLSvr MESSAGE=' 
                             + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
         FETCH NEXT FROM CUR_PD INTO @c_GetPickdetailkey, @c_trmlogkey
      END
      CLOSE CUR_PD
      DEALLOCATE CUR_PD
   END

   IF @b_Debug IN (1,2)
   BEGIN
      SELECT PD.CartonGroup, PD.* 
      FROM PICKDETAIL PD (NOLOCK)
      JOIN #TMP_PICK TP ON TP.PickdetailKey = PD.PickDetailKey
      ORDER BY PD.PickDetailKey
   END

   IF (@n_Continue = 1 OR @n_Continue = 2) AND @b_Debug IN (0)
   BEGIN
      --Insert actual Transmitlog2 table
      DECLARE CUR_TKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT TT.TLogKey, TT.TableName, TT.TKEY2, TT.TKEY3
      FROM #TMP_TKEY TT
      ORDER BY TT.TLogKey
       
      OPEN CUR_TKEY
      
      FETCH NEXT FROM CUR_TKEY INTO @c_trmlogkey, @c_TableName, @c_TLKey2, @c_GetStorerkey
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         INSERT INTO Transmitlog2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)
         VALUES (@c_trmlogkey, @c_TableName, @c_trmlogkey, @c_TLKey2, @c_GetStorerkey, '0', '')

         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63830   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) 
                             + ': Unable to insert into Transmitlog2 table. (isp_BackendPickTaskAutoSort) ( SQLSvr MESSAGE=' 
                             + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END

         FETCH NEXT FROM CUR_TKEY INTO @c_trmlogkey, @c_TableName, @c_TLKey2, @c_GetStorerkey
      END
      CLOSE CUR_TKEY
      DEALLOCATE CUR_TKEY
   END

QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_B2B') IN (0 , 1)
   BEGIN
      CLOSE CUR_B2B
      DEALLOCATE CUR_B2B   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_B2C') IN (0 , 1)
   BEGIN
      CLOSE CUR_B2C
      DEALLOCATE CUR_B2C  
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP  
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_TKEY') IN (0 , 1)
   BEGIN
      CLOSE CUR_TKEY
      DEALLOCATE CUR_TKEY  
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_PD') IN (0 , 1)
   BEGIN
      CLOSE CUR_PD
      DEALLOCATE CUR_PD  
   END
   
   IF OBJECT_ID('tempdb..#TMP_PICK') IS NOT NULL
      DROP TABLE #TMP_PICK

   IF OBJECT_ID('tempdb..#TMP_TKEY') IS NOT NULL
      DROP TABLE #TMP_TKEY

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_BackendPickTaskAutoSort'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
        COMMIT TRAN
      END 
      RETURN
   END 
END

GO