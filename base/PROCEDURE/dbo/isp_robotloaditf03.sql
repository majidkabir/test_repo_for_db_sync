SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_RobotLoadITF03                                      */
/* Creation Date: 25-Apr-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19534 - CN_LOreal_Exceed_BulidLoad_Order_Trigger        */                                         
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
/* 25-Apr-2022 WLChooi  1.0   DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[isp_RobotLoadITF03]
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
         , @c_Key1             NVARCHAR(50)
         , @c_Key2             NVARCHAR(50)
         , @c_Key3             NVARCHAR(50)
         , @c_TableName        NVARCHAR(50)
         , @c_Authority        NVARCHAR(30)
         , @c_Option1          NVARCHAR(50)
         , @c_Option2          NVARCHAR(50)
         , @c_Option3          NVARCHAR(50)
         , @c_Option4          NVARCHAR(50)
         , @c_Option5          NVARCHAR(4000)
         , @c_Storerkey        NVARCHAR(15)
         , @c_Facility         NVARCHAR(5)
         , @c_TransmitLogKey   NVARCHAR(10)

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt = @@TRANCOUNT, @c_errmsg = '', @n_err = 0

   SELECT @c_Facility   = MAX(OH.Facility)
        , @c_Storerkey  = MAX(OH.StorerKey)
        , @c_Loadkey    = MAX(LPD.LoadKey)
   FROM LOADPLANDETAIL LPD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
   WHERE LPD.LoadKey = @c_Loadkey

   EXEC [dbo].[nspGetRight] @c_Facility   = @c_Facility          
                          , @c_StorerKey  = @c_Storerkey                
                          , @c_sku        = NULL                       
                          , @c_ConfigKey  = N'RobotLoadITF_SP'                 
                          , @b_Success    = @b_Success OUTPUT     
                          , @c_authority  = @c_Authority OUTPUT 
                          , @n_err        = @n_err OUTPUT             
                          , @c_errmsg     = @c_errmsg OUTPUT       
                          , @c_Option1    = @c_Option1 OUTPUT     
                          , @c_Option2    = @c_Option2 OUTPUT     
                          , @c_Option3    = @c_Option3 OUTPUT     
                          , @c_Option4    = @c_Option4 OUTPUT     
                          , @c_Option5    = @c_Option5 OUTPUT     

   SET @c_TableName = @c_Option1

   IF ISNULL(@c_TableName,'') = ''    
   BEGIN      
      SET @n_continue = 3      
      SET @n_err = 65335   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
      SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Storerconfig.Option1 is blank. (isp_RobotLoadITF03)' + 
                               ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '      
      GOTO QUIT_SP  
   END

   IF @@TRANCOUNT = 0
      BEGIN TRAN
   
   IF @n_Continue IN (1,2)
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
         SET @n_err = 65340   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain TransmitLogKey2. (isp_RobotLoadITF03)' + 
                                  ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '      
         GOTO QUIT_SP  
      END 
               
      INSERT INTO TRANSMITLOG2 (transmitlogkey, tablename, key1, key2, key3, transmitflag)
      SELECT @c_TransmitLogKey, @c_TableName, @c_Loadkey, '', TRIM(@c_Storerkey), '0'
      
      SELECT @n_err = @@ERROR  
               
      IF @n_err <> 0  
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 65345    
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                          + ': Insert Failed On Table TRANSMITLOG2. (isp_RobotLoadITF03)'   
                          + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
      END 
   END

QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RobotLoadITF03'
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