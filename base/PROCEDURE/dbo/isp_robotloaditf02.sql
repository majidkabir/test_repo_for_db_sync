SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_RobotLoadITF02                                      */
/* Creation Date: 31-May-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-17135 - CN_MAST AGV B2B Wave for Loadplan Summary       */
/*          Trigger Point                                               */                                           
/*        :                                                             */
/* Called By: isp_RobotLoadITF_Wrapper                                  */
/*          :                                                           */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_RobotLoadITF02]
           @c_Loadkey   NVARCHAR(10) 
         , @b_Success   INT            OUTPUT
         , @n_Err       INT            OUTPUT
         , @c_ErrMsg    NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue         INT
         , @n_starttcnt        INT
         , @c_DocType          NVARCHAR(10)
         , @c_B2BTableName     NVARCHAR(20)
         , @c_B2CTableName     NVARCHAR(20)
         , @c_Key1             NVARCHAR(50)
         , @c_Key2             NVARCHAR(50)
         , @c_Key3             NVARCHAR(50)
         , @c_TableName        NVARCHAR(50)
         , @c_TransmitLogKey   NVARCHAR(10)
         , @c_MinDocType       NVARCHAR(10)
         , @c_MaxDocType       NVARCHAR(10)
         , @c_Facility         NVARCHAR(10)
         , @c_SpecialNumber    NVARCHAR(5)
         , @n_CountOrdKey        INT
         , @c_Storerkey        NVARCHAR(15)
         , @c_ESingleFlag      NVARCHAR(1)

   CREATE TABLE #TMP_LP (
        Key1      NVARCHAR(50)
      , Key2      NVARCHAR(50)
      , Key3      NVARCHAR(50)
      , TableName NVARCHAR(50)
   )

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0

   SET @c_B2BTableName = 'WSSOB2BAGV'
   SET @c_B2CTableName = 'WSSOB2CAGV'

   SELECT @c_MinDocType = MIN(OH.DocType)
        , @c_MaxDocType = MAX(OH.DocType)
        , @c_Facility   = MAX(OH.Facility)
        , @c_Storerkey  = MAX(OH.StorerKey)
        , @c_ESingleFlag = MAX(OH.ECOM_SINGLE_Flag)
   FROM LOADPLANDETAIL LPD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
   WHERE LPD.LoadKey = @c_Loadkey

   IF @c_MinDocType <> @c_MaxDocType
   BEGIN
      SET @n_Continue= 3    
      SET @n_Err     = 62085    
      SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Mixing ECOM and Normal DocType is found in Load.'  
                     + '.(isp_RobotLoadITF02)'
      GOTO QUIT_SP  
   END

   SET @c_DocType = @c_MaxDocType

   SELECT @c_SpecialNumber = CASE WHEN ISNUMERIC(CL.Short) = 1 THEN CL.Short ELSE '0' END
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'AGVEBNV'
   AND CL.Storerkey = @c_Storerkey
   AND CL.Code = @c_Facility

   IF @c_DocType = 'N'
   BEGIN
      INSERT INTO #TMP_LP (Key1, Key2, Key3, TableName)  
      SELECT DISTINCT PH.Pickheaderkey, LPD.Loadkey, OH.Storerkey, @c_B2BTableName
      FROM LOADPLANDETAIL LPD (NOLOCK)
      JOIN PICKHEADER PH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
      JOIN ORDERS OH (NOLOCK) ON LPD.OrderKey = OH.OrderKey
      WHERE LPD.LoadKey = @c_Loadkey
   END
   ELSE IF @c_DocType = 'E'
   BEGIN
      INSERT INTO #TMP_LP (Key1, Key2, Key3, TableName)
      SELECT DISTINCT PD.PickSlipNo, LPD.Loadkey, PD.Storerkey, @c_B2CTableName
      FROM LOADPLANDETAIL LPD (NOLOCK)
      JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = LPD.OrderKey
      WHERE LPD.LoadKey = @c_Loadkey
   END
   ELSE
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 62090
      SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ ': DocType Not Valid. (isp_RobotLoadITF02)'
                    + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
      GOTO QUIT_SP
   END

   IF EXISTS (SELECT 1 FROM #TMP_LP TW (NOLOCK)
              WHERE TW.TableName = 'WSSOB2BAGV'
              AND ISNULL(TW.Key1,'') = '' )
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 62095
      SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ ':Pickheader.Pickheaderkey is Blank (B2B). (isp_RobotLoadITF02)'
                    + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
      GOTO QUIT_SP
   END

   IF EXISTS (SELECT 1 FROM #TMP_LP TW (NOLOCK)
              WHERE TW.TableName = 'WSSOB2CAGV'
              AND ISNULL(TW.Key1,'') = '' )
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 62100
      SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ ':Pickdetail.Pickslipno is Blank (B2C). (isp_RobotLoadITF02)'
                    + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
      GOTO QUIT_SP
   END

   IF @c_DocType = 'E'
   BEGIN
      IF EXISTS (SELECT 1
                 FROM LOADPLANDETAIL LPD (NOLOCK)
                 JOIN ORDERS OH (NOLOCK) ON LPD.OrderKey = OH.OrderKey
                 JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = LPD.OrderKey
                 LEFT JOIN TASKDETAIL TD1 (NOLOCK) ON TD1.TaskDetailKey = PD.TaskDetailKey
                 LEFT JOIN TASKDETAIL TD2 (NOLOCK) ON TD2.tasktype IN ('RPT', 'RP1', 'RPF')
                                                  AND TD2.ListKey = TD1.ListKey
                                                  AND TD1.ListKey <> ''
                 WHERE OH.Doctype = 'E'
                 AND PD.TaskDetailKey <> ''
                 AND ISNULL(TD1.[Status],'') <> 'X'
                 AND ISNULL(TD2.[Status],'') <> '9'
                 AND LPD.LoadKey = @c_Loadkey)
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 62105
         SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ ':Wave Replenishment is not done yet (B2C). (isp_RobotLoadITF02)'
                       + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
         GOTO QUIT_SP
      END

      IF @c_ESingleFlag = 'M'
      BEGIN
         IF EXISTS (SELECT 1
                    FROM PICKDETAIL PD (NOLOCK)
                    JOIN LoadPlanDetail LD (NOLOCK) ON LD.OrderKey = PD.OrderKey
                    WHERE PD.Storerkey = @c_Storerkey and LD.Loadkey = @c_Loadkey
                    GROUP BY PD.PickSlipNo
                    HAVING COUNT(DISTINCT PD.Orderkey) > @c_SpecialNumber)
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 62106
            SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ ':Abnormal TaskbatchNo Release to AGV for multi load (B2C). (isp_RCM_WV_MAST_AGVGenITF)'
                          + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
            GOTO QUIT_SP
         END
      END
   END

   IF @@TRANCOUNT = 0
      BEGIN TRAN
   
   IF @n_Continue IN (1,2)
   BEGIN
      DECLARE CUR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT TW.Key1, TW.Key2, TW.Key3, TW.TableName
      FROM #TMP_LP TW (NOLOCK)
      
      OPEN CUR_LOAD    
       
      FETCH NEXT FROM CUR_LOAD INTO @c_Key1, @c_Key2, @c_Key3, @c_TableName
      
      WHILE @@FETCH_STATUS <> -1    
      BEGIN 
         --Insert Transmitlog2
         SELECT @b_success = 1
         
         EXECUTE nspg_getkey      
            'TransmitLogKey2'      
            , 10      
            , @c_TransmitLogKey OUTPUT      
            , @b_success        OUTPUT      
            , @n_err            OUTPUT      
            , @c_errmsg         OUTPUT      
                  
         IF NOT @b_success = 1      
         BEGIN      
            SET @n_continue = 3      
            SET @n_err = 62110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain TransmitLogKey2. (isp_RobotLoadITF02)' + 
                                     ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '      
            GOTO QUIT_SP  
         END 
                  
         INSERT INTO TRANSMITLOG2 (transmitlogkey, tablename, key1, key2, key3, transmitflag)
         SELECT @c_TransmitLogKey, @c_TableName, @c_Key1, @c_Key2, @c_Key3, '0'
         
         SELECT @n_err = @@ERROR  
                  
         IF @n_err <> 0  
         BEGIN
            SELECT @n_continue = 3  
            SELECT @n_err = 62115    
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                             + ': Insert Failed On Table TRANSMITLOG2. (isp_RobotLoadITF02)'   
                             + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
         END 

         UPDATE LOADPLAN
         SET UserDefine01 = 'Y'
           , TrafficCop   = NULL
           , EditDate     = GETDATE()
           , EditWho      = SUSER_SNAME()
         WHERE LoadKey = @c_Key2
         
         SELECT @n_err = @@ERROR  
                  
         IF @n_err <> 0  
         BEGIN
            SELECT @n_continue = 3  
            SELECT @n_err = 62120    
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                             + ': Update Failed On Table LOADPLAN. (isp_RobotLoadITF02)'   
                             + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END

         FETCH NEXT FROM CUR_LOAD INTO @c_Key1, @c_Key2, @c_Key3, @c_TableName
      END
   END

QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_LOAD') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOAD
      DEALLOCATE CUR_LOAD   
   END

   IF OBJECT_ID('tempdb..#TMP_LP') IS NOT NULL
      DROP TABLE #TMP_LP

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RobotLoadITF02'
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