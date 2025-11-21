SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: nspLPRTSK11                                         */  
/* Creation Date: 18-AUG-2020                                            */  
/* Copyright: LFL                                                        */  
/* Written by: WLChooi                                                   */  
/*                                                                       */  
/* Purpose: WMS-14764 - CN_MAST_Rcm_release_pick_task                    */
/*                                                                       */  
/* Called By: Load                                                       */  
/*                                                                       */  
/* GitLab Version: 1.1                                                   */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/*2020-10-12    WLChooi  1.1  Fix Storerkey (WL01)                       */
/*************************************************************************/   

CREATE PROCEDURE [dbo].[nspLPRTSK11]      
     @c_LoadKey      NVARCHAR(10) 
    ,@n_err          int            OUTPUT  
    ,@c_errmsg       NVARCHAR(250)  OUTPUT  
    ,@c_Storerkey    NVARCHAR(15) = '' 
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
    
   DECLARE @n_continue    INT,    
           @n_starttcnt   INT,         -- Holds the current transaction count  
           @n_debug       INT,
           @b_success     INT,  
           @n_cnt         INT,
           @c_trmlogkey   NVARCHAR(10),
           @c_BatchNo     NVARCHAR(10)

   DECLARE @c_APP_DB_Name        NVARCHAR(20)   = ''  
         , @c_DataStream         VARCHAR(10)    = ''  
         , @n_ThreadPerAcct      INT            = 0  
         , @n_ThreadPerStream    INT            = 0  
         , @n_MilisecondDelay    INT            = 0  
         , @c_IP                 NVARCHAR(20)   = ''  
         , @c_PORT               NVARCHAR(5)    = ''  
         , @c_IniFilePath        NVARCHAR(100)  = '' 
         , @c_CmdType            NVARCHAR(10)   = ''  
         , @c_TaskType           NVARCHAR(1)    = ''  
         , @c_Command            NVARCHAR(4000) = '' 
         , @c_OriCommand         NVARCHAR(4000) = '' 
            
   SELECT  @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
   SELECT  @n_debug = 0
   
   DECLARE  @c_Facility            NVARCHAR(5)  
           ,@c_SourceType          NVARCHAR(30)

   IF ISNULL(@c_Storerkey,'') = ''
   BEGIN
      SELECT @c_Storerkey = Storerkey
      FROM ORDERS (NOLOCK) 
      WHERE Loadkey = @c_LoadKey
   END

   CREATE TABLE #TEMP_TABLE (
      Loadkey      NVARCHAR(10) NULL,
      Orderkey     NVARCHAR(10) NULL,
      Pickslipno   NVARCHAR(10) NULL
   )
                           
   SET @c_SourceType = 'nspLPRTSK11'    

   INSERT INTO #TEMP_TABLE
   SELECT LPD.Loadkey, PD.Orderkey, PD.Pickslipno
   FROM PICKDETAIL PD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = PD.Orderkey
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.Orderkey = OH.Orderkey
   WHERE LPD.Loadkey = @c_LoadKey

   --Validation
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM #TEMP_TABLE WHERE ISNULL(Pickslipno,'') = '')
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 89010    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Orderkey Has Empty BatchNo. (nspLPRTSK11)'    
         GOTO QUIT_SP   
      END       
   END
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
   	SELECT @c_APP_DB_Name         = APP_DB_Name  
           , @c_DataStream          = DataStream  
           , @n_ThreadPerAcct       = ThreadPerAcct  
           , @n_ThreadPerStream     = ThreadPerStream  
           , @n_MilisecondDelay     = MilisecondDelay  
           , @c_IP                  = IP  
           , @c_PORT                = PORT  
           , @c_IniFilePath         = IniFilePath  
           , @c_CmdType             = CmdType  
           , @c_TaskType            = TaskType  
           , @c_Command             = StoredProcName
      FROM  QCmd_TransmitlogConfig WITH (NOLOCK)  
      WHERE TableName  = 'WSPICKVCLOG'  
      AND   [App_Name] = 'WOL_OUT'  
      AND   StorerKey  = @c_Storerkey   --WL01

      SET @c_Command = REPLACE(@c_Command, '@c_StorerKey=''ALL''', '@c_StorerKey=''18455''')
      SET @c_OriCommand = @c_Command
      
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Pickslipno
      FROM #TEMP_TABLE

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_BatchNo

      WHILE @@FETCH_STATUS <> -1
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
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 89015   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain transmitlogkey2. (nspLPRTSK11)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            GOTO QUIT_SP  
         END
         ELSE
         BEGIN
            INSERT INTO Transmitlog2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)
            VALUES (@c_trmlogkey, 'WSPICKVCLOG', @c_BatchNo, @c_Loadkey, @c_StorerKey, '0', '')
         
            SET @n_err = @@ERROR
            IF @n_err <> 0    
            BEGIN  
               SELECT @n_continue = 3    
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 89020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Transmitlog2 Failed. (nspLPRTSK11)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
               GOTO QUIT_SP  
            END  
            
            SET @c_Command = @c_OriCommand + ' ,@c_TransmitlogKey = ''' + @c_trmlogkey + ''''
            
            BEGIN TRY  
            EXEC isp_QCmd_SubmitTaskToQCommander  
                 @cTaskType         = 'D' -- D=By Datastream, T=Transmitlog, O=Others  
               , @cStorerKey        = @c_StorerKey  
               , @cDataStream       = @c_DataStream 
               , @cCmdType          = 'SQL'  
               , @cCommand          = @c_Command  
               , @cTransmitlogKey   = @c_trmlogkey  
               , @nThreadPerAcct    = @n_ThreadPerAcct  
               , @nThreadPerStream  = @n_ThreadPerStream  
               , @nMilisecondDelay  = @n_MilisecondDelay  
               , @nSeq              = 1  
               , @cIP               = @c_IP  
               , @cPORT             = @c_PORT  
               , @cIniFilePath      = @c_IniFilePath  
               , @cAPPDBName        = @c_APP_DB_Name  
               , @bSuccess          = @b_Success OUTPUT  
               , @nErr              = @n_Err OUTPUT  
               , @cErrMsg           = @c_ErrMsg OUTPUT  
         
            END TRY  
            BEGIN CATCH  
               SET @n_continue = '3'
               SET @c_ErrMsg = ERROR_MESSAGE()  
               GOTO QUIT_SP  
            END CATCH   
         END
         
         FETCH NEXT FROM CUR_LOOP INTO @c_BatchNo
      END
   END

 

QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   IF OBJECT_ID('tempdb..#TEMP_TABLE') IS NOT NULL
      DROP TABLE #TEMP_TABLE

   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_starttcnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      execute nsp_logerror @n_err, @c_errmsg, "nspLPRTSK11"  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END      
END --sp end

GO