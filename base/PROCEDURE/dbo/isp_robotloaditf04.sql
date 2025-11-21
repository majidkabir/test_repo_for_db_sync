SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_RobotLoadITF04                                      */
/* Creation Date: 14-Sep-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20772 - CN_Columbia Omini Sort B2B and B2C Loadplan     */
/*          Summary Trigger Point                                       */                                    
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
/* 14-Sep-2022 WLChooi  1.0   DevOps Combine Script                     */
/* 17-Jan-2023 CHONGCS  1.1   WMS-21536 add filter (CS01)               */
/************************************************************************/
CREATE   PROC [dbo].[isp_RobotLoadITF04]
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
         , @c_Storerkey        NVARCHAR(15)
         , @c_Option1          NVARCHAR(30)
         , @c_Option2          NVARCHAR(30)
         , @c_Option3          NVARCHAR(30)
         , @c_Option4          NVARCHAR(30)
         , @c_Option5          NVARCHAR(4000)
         , @c_authority        NVARCHAR(50)
         , @n_Count            INT = 0
         , @n_MaxCount         INT = 0

   CREATE TABLE #TMP_LP (
        Key1      NVARCHAR(50)
      , Key2      NVARCHAR(50)
      , Key3      NVARCHAR(50)
      , TableName NVARCHAR(50)
      , DocType   NVARCHAR(10)
   )

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0

   SET @c_B2BTableName = 'WSRCSBHB2B'
   SET @c_B2CTableName = 'WSRCSBHB2C'

   SELECT @c_MinDocType = MIN(OH.DocType)
        , @c_MaxDocType = MAX(OH.DocType)
        , @c_Facility   = MAX(OH.Facility)
        , @c_Storerkey  = MAX(OH.StorerKey)
   FROM LOADPLANDETAIL LPD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
   WHERE LPD.LoadKey = @c_Loadkey

   IF @c_MinDocType <> @c_MaxDocType
   BEGIN
      SET @n_Continue= 3    
      SET @n_Err     = 62085    
      SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Mixing ECOM and Normal DocType is found in Load.'  
                     + '.(isp_RobotLoadITF04)'
      GOTO QUIT_SP  
   END

   IF EXISTS (SELECT 1
              FROM LOADPLANDETAIL LPD (NOLOCK)
              JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
              JOIN PICKDETAIL PD (NOLOCK) ON OH.OrderKey = PD.OrderKey
              WHERE LPD.LoadKey = @c_Loadkey
              AND ISNULL(PD.PickSlipNo,'') = ''
              AND PD.UOM <>'2' )    --CS01
   BEGIN
      SET @n_Continue= 3    
      SET @n_Err     = 62095   
      SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': PICKDETAIL.Pickslipno is blank for Loadkey# '
                     + @c_Loadkey
                     + '.(isp_RobotLoadITF04)'
      GOTO QUIT_SP 
   END

   SELECT TOP 1 @n_MaxCount = CASE WHEN ISNUMERIC(CL.UDF01) = 1 THEN CL.UDF01 ELSE 0 END
   FROM CODELKUP CL (NOLOCK) 
   WHERE CL.LISTNAME ='CBPCMAXORD'
   AND CL.Storerkey = @c_Storerkey

   SET @c_DocType = @c_MaxDocType

   EXEC dbo.nspGetRight @c_Facility = NULL             
                      , @c_StorerKey = @c_Storerkey              
                      , @c_sku = NULL                     
                      , @c_ConfigKey = N'RobotLoadITF_SP'                
                      , @b_Success     = @b_Success   OUTPUT    
                      , @c_authority   = @c_authority OUTPUT
                      , @n_err         = @n_err       OUTPUT            
                      , @c_errmsg      = @c_errmsg    OUTPUT      
                      , @c_Option1     = @c_Option1   OUTPUT    
                      , @c_Option2     = @c_Option2   OUTPUT    
                      , @c_Option3     = @c_Option3   OUTPUT    
                      , @c_Option4     = @c_Option4   OUTPUT    
                      , @c_Option5     = @c_Option5   OUTPUT  

   IF @c_authority = 'isp_RobotLoadITF04'
   BEGIN
      SELECT @c_B2BTableName = dbo.fnc_GetParamValueFromString('@c_B2BTableName', @c_Option5, @c_B2BTableName)  

      IF ISNULL(@c_B2BTableName,'') = ''
         SET @c_B2BTableName = 'WSRCSBHB2B'

      SELECT @c_B2CTableName = dbo.fnc_GetParamValueFromString('@c_B2CTableName', @c_Option5, @c_B2CTableName)  

      IF ISNULL(@c_B2CTableName,'') = ''
         SET @c_B2CTableName = 'WSRCSBHB2C'
   END

   INSERT INTO #TMP_LP (Key1, Key2, Key3, TableName, DocType)
   SELECT DISTINCT PD.PickSlipNo, LPD.Loadkey, PD.Storerkey
                 , CASE WHEN TRIM(@c_DocType) = 'E' THEN @c_B2CTableName
                        WHEN TRIM(@c_DocType) = 'N' THEN @c_B2BTableName
                        ELSE '' END
                 , @c_DocType
   FROM LOADPLANDETAIL LPD (NOLOCK)
   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = LPD.OrderKey
   WHERE LPD.LoadKey = @c_Loadkey
   AND PD.UOM <>'2'     --CS01

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   IF @@TRANCOUNT = 0
      BEGIN TRAN

   IF @n_Continue IN (1,2)
   BEGIN
      DECLARE CUR_CHECK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT DISTINCT TW.Key1, TW.DocType
      FROM #TMP_LP TW (NOLOCK)
      WHERE TW.DocType IN ('N','E')
      
      OPEN CUR_CHECK
      
      FETCH NEXT FROM CUR_CHECK INTO @c_Key1, @c_DocType
      
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @n_Count = 0
         
         IF @c_DocType = 'N'
         BEGIN
            SELECT @n_Count = COUNT(DISTINCT PD.Notes)
            FROM PICKDETAIL PD (NOLOCK)
            WHERE PD.PickSlipNo = @c_Key1
         END
         ELSE IF @c_DocType = 'E'
         BEGIN
            SELECT @n_Count = COUNT(DISTINCT PD.OrderKey)
            FROM PICKDETAIL PD (NOLOCK)
            WHERE PD.PickSlipNo = @c_Key1
         END
         
         IF @n_Count > @n_MaxCount
         BEGIN
            SET @n_Continue= 3    
            SET @n_Err     = 62100   
            SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Pickslipno# ' + @c_Key1 
                           + ' is over max physical position of Omni sort device.'  
                           + '.(isp_RobotLoadITF04)'
            GOTO QUIT_SP 
         END
      
         FETCH NEXT FROM CUR_CHECK INTO @c_Key1, @c_DocType
      END
      CLOSE CUR_CHECK
      DEALLOCATE CUR_CHECK
   END
   
   IF @n_Continue IN (1,2)
   BEGIN
      DECLARE CUR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT TW.Key1, TW.Key2, TW.Key3, TW.TableName
      FROM #TMP_LP TW (NOLOCK)
      WHERE TW.DocType IN ('N','E')
      
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
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain TransmitLogKey2. (isp_RobotLoadITF04)' + 
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
                             + ': Insert Failed On Table TRANSMITLOG2. (isp_RobotLoadITF04)'   
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
                             + ': Update Failed On Table LOADPLAN. (isp_RobotLoadITF04)'   
                             + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END

         FETCH NEXT FROM CUR_LOAD INTO @c_Key1, @c_Key2, @c_Key3, @c_TableName
      END
      CLOSE CUR_LOAD
      DEALLOCATE CUR_LOAD 
   END

QUIT_SP:
   IF ISNULL(@c_errmsg,'') = ''
      SET @c_errmsg = 'EDI record generated successfully'
   ELSE
      SET @c_errmsg = 'EDI record generated failed. ' + @c_errmsg

   IF CURSOR_STATUS('LOCAL', 'CUR_LOAD') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOAD
      DEALLOCATE CUR_LOAD   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_CHECK') IN (0 , 1)
   BEGIN
      CLOSE CUR_CHECK
      DEALLOCATE CUR_CHECK   
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RobotLoadITF04'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN
END -- procedure

GO