SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/          
/* Stored Procedure: isp_Carrier_Middleware_Interface                   */          
/* Creation Date: 05-APR-2023                                           */          
/* Copyright: LFL                                                       */          
/* Written by:                                                          */          
/*                                                                      */          
/* Purpose: WMS-22115 - AU - Carrier middleware interface for all storer*/        
/*                                                                      */      
/*                                                                      */          
/* Called By: RDT, WMS or Interface                                     */          
/*                                                                      */          
/* GitLab Version: 1.0                                                  */          
/*                                                                      */          
/* Version: 7.0                                                         */          
/*                                                                      */          
/* Data Modifications:                                                  */          
/*                                                                      */          
/* Updates:                                                             */          
/* Date         Author  Rev   Purposes                                  */       
/* 05-APR-2023  NJOW    1.0   Devops Combine Script                     */ 
/* 09-May-2023  Khor    1.1   JSM-148371 - Push TL2 Records to Qcmd     */
/*                            Queue right after it generated.           */      
/************************************************************************/          
CREATE   PROC [dbo].[isp_Carrier_Middleware_Interface]            
     @c_OrderKey    NVARCHAR(10) = ''         
   , @c_Mbolkey     NVARCHAR(10) = ''      
   , @c_FunctionID  NVARCHAR(10) = ''          
   , @n_CartonNo    INT = 0      
   , @n_Step        INT = 0      
   , @b_Success     INT           OUTPUT            
   , @n_Err         INT           OUTPUT            
   , @c_ErrMsg      NVARCHAR(250) OUTPUT            
AS            
BEGIN            
   SET NOCOUNT ON         
   SET QUOTED_IDENTIFIER OFF         
   SET ANSI_NULLS OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF                 
            
   DECLARE  @n_Continue              INT,            
            @n_StartTCnt             INT, -- Holds the current transaction count        
            @c_SQL                   NVARCHAR(MAX),      
            @c_Storerkey             NVARCHAR(15),      
            @c_GetStorerkey          NVARCHAR(15),      
            @c_Facility              NVARCHAR(5),      
            @c_Loadkey               NVARCHAR(10),      
            @c_Wavekey               NVARCHAR(10),      
            @c_Code                  NVARCHAR(30),      
            @c_Type                  NVARCHAR(30),      
            @c_Notes                 NVARCHAR(MAX),      
            @c_UDF01                 NVARCHAR(60),      
            @c_UDF02                 NVARCHAR(60),      
            @c_WSCourier             NVARCHAR(1),      
            @n_IsRDT                 INT = 0,      
            @c_TableName             NVARCHAR(30),      
            @c_Key1                  NVARCHAR(10),              
            @c_Key2                  NVARCHAR(30),              
            @c_Key3                  NVARCHAR(20)    
    
    DECLARE @c_TargetDB         NVARCHAR(30),          --JSM-148371 Start
            @c_TargetSchema     NVARCHAR(20) = 'dbo',    
            @c_TransmitLogKey   NVARCHAR(10),    
            @c_ExecStatements   NVARCHAR(4000),    
            @c_ExecArguments    NVARCHAR(4000),    
            @b_Debug            INT                    --JSM-148371 End
       
    SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue = 1, @b_Success = 1, @n_Err = 0, @c_ErrMsg = ''          
         
    SET @n_CartonNo = ISNULL(@n_CartonNo,0)      
         
    IF OBJECT_ID ('tempdb..#TMP_Transmitlog', 'U') IS NOT NULL            DROP TABLE #TMP_Transmitlog        
        
    CREATE TABLE #TMP_Transmitlog (               
         tablename NVARCHAR(30)      
        ,Key1 NVARCHAR(10)      
        ,Key2    NVARCHAR(30)      
        ,Key3     NVARCHAR(20))      
      
    IF OBJECT_ID ('tempdb..#TMP_Transmitlog_Work', 'U') IS NOT NULL      
       DROP TABLE #TMP_Transmitlog_Work        
      
    CREATE TABLE #TMP_Transmitlog_Work (               
        Key1    NVARCHAR(10)      
       ,Key2    NVARCHAR(30)      
       ,Key3     NVARCHAR(20))      
           
    IF ISNULL(@c_OrderKey,'') = '' AND ISNULL(@c_MBOLKey,'') = ''      
    BEGIN      
      SELECT @n_Continue = 3                                                                                                                                                                    
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                                  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Must provide Orderkey or Mbolkey (isp_Carrier_Middleware_Interface)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '              
      GOTO EXIT_SP                            
    END      
      
    IF ISNULL(@c_FunctionID,'') = ''      
    BEGIN      
      SELECT @n_Continue = 3                                                                                                                                                                    
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                                  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': FunctionId cannot be empty (isp_Carrier_Middleware_Interface)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '              
      GOTO EXIT_SP                            
    END      
               
   --Prepare data      
   IF @n_continue IN(1,2)      
   BEGIN       
      EXEC RDT.rdtIsRDT @n_IsRDT OUTPUT         
      
      IF ISNULL(@c_Orderkey,'') <> ''       
      BEGIN                
         SELECT TOP 1 @c_Storerkey = O.Storerkey,      
                      @c_Facility = O.Facility,      
                      @c_Mbolkey = O.Mbolkey,      
                      @c_Loadkey = O.Loadkey,      
                      @c_Wavekey = O.Userdefine09,      
                      @c_WSCourier  = CASE WHEN CL.Code IS NOT NULL THEN 'Y' ELSE 'N' END      
         FROM ORDERS O (NOLOCK)      
         LEFT JOIN CODELKUP CL (NOLOCK) ON O.Storerkey = CL.Storerkey AND O.Shipperkey = CL.Short AND CL.Listname = 'WSCOURIER' AND CL.Code2 = 'MW'      
         WHERE O.Orderkey = @c_Orderkey      
      
        IF ISNULL(@c_Storerkey,'') = ''      
        BEGIN      
            SELECT @n_Continue = 3                                                                                                                                                                    
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                                  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Orderkey ' +  RTRIM(@c_Orderkey) + '. (isp_Carrier_Middleware_Interface)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '              
            GOTO EXIT_SP                            
        END      
      END      
      ELSE IF ISNULL(@c_Mbolkey, '') <> ''      
      BEGIN      
         SELECT TOP 1 @c_Storerkey = O.Storerkey,      
                      @c_Facility = O.Facility,      
                      @c_Loadkey = O.Loadkey,      
                      @c_Wavekey = O.Userdefine09,      
                      @c_WSCourier  = CASE WHEN CL.Code IS NOT NULL THEN 'Y' ELSE 'N' END      
         FROM ORDERS O (NOLOCK)      
         LEFT JOIN CODELKUP CL (NOLOCK) ON O.Storerkey = CL.Storerkey AND O.Shipperkey = CL.Short AND CL.Listname = 'WSCOURIER' AND CL.Code2 = 'MW'      
         WHERE O.Mbolkey = @c_Mbolkey      
      
        IF ISNULL(@c_Storerkey,'') = ''      
        BEGIN      
            SELECT @n_Continue = 3                                                                                                             
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                                  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Mbolkey ' +  RTRIM(@c_Mbolkey) + '. (isp_Carrier_Middleware_Interface)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            GOTO EXIT_SP                            
        END      
      END      
      ELSE       
      BEGIN      
         SELECT @n_Continue = 3                                                                                                                                                                    
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                                  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid setup. Orderkey or Mbolkey must specify (isp_Carrier_Middleware_Interface)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '              
         GOTO EXIT_SP                        
      END      
   END      
      
   IF @@TRANCOUNT = 0      
      BEGIN TRAN      
         
   --Generate tranmsitlog data by codelkup conditions      
   IF @n_continue IN(1,2)      
   BEGIN      
      IF EXISTS(SELECT 1 FROM CODELKUP (NOLOCK) WHERE Code2 = @c_FunctionID AND Storerkey = @c_Storerkey)  --if the storer has setup in codelkup      
      BEGIN      
         DECLARE CUR_TYPE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
            SELECT DISTINCT Long, Storerkey      
            FROM CODELKUP (NOLOCK)      
            WHERE Code2 = @c_FunctionID      
            AND ListName = 'MDWCARRIER'      
            AND Storerkey = @c_Storerkey      
      END      
      ELSE      
      BEGIN      
         DECLARE CUR_TYPE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
            SELECT DISTINCT Long, Storerkey      
            FROM CODELKUP (NOLOCK)      
            WHERE Code2 = @c_FunctionID      
            AND ListName = 'MDWCARRIER'      
            AND Storerkey IN('ALL','')               
      END      
            
      OPEN CUR_TYPE          
                  
      FETCH NEXT FROM CUR_TYPE INTO @c_Type, @c_GetStorerkey         
              
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)        
      BEGIN            
         DECLARE CUR_TYPEDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
           SELECT Code, Notes, UDF01, UDF02      
            FROM CODELKUP (NOLOCK)      
            WHERE Code2 = @c_FunctionID      
            AND ListName = 'MDWCARRIER'      
            AND Long = @c_Type      
            AND Storerkey = @c_GetStorerkey      
            ORDER BY Code      
                  
         OPEN CUR_TYPEDETAIL          
                  
         FETCH NEXT FROM CUR_TYPEDETAIL INTO @c_Code, @c_Notes, @c_UDF01, @c_UDF02      
                 
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  --loop for each line of same storerkey, type and functionid       
         BEGIN             
           SET @c_SQL = @c_Notes      
           SET @c_TableName = ''      
           TRUNCATE TABLE #TMP_Transmitlog_Work      
                        
           IF ISNULL(@c_SQL,'') = '' AND @n_continue IN(1,2)      
           BEGIN      
               SELECT @n_Continue = 3                                                                                                                                                                    
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                                  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid setup. Empty SQL Condition. Code:' +  RTRIM(@c_Code) +' Func:' + RTRIM(@c_FunctionID) + ' Type:' + RTRIM(@c_Type) +  ' Storer:' +RTRIM(@c_GetStorerkey)       
                + ' (isp_Carrier_Middleware_Interface)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                            
           END      
                 
           IF @n_IsRDT = 1 AND CHARINDEX('@n_Step', @c_SQL) = 0 AND @n_continue IN(1,2)      
            BEGIN      
               SELECT @n_Continue = 3                                                                                                                                                                    
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                            
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid setup. Must specify step for RDT. Code:' +  RTRIM(@c_Code) +' Func:' + RTRIM(@c_FunctionID) + ' Type:' + RTRIM(@c_Type) +  ' Storer:' +RTRIM(@c_GetStorerkey)       
                                + ' (isp_Carrier_Middleware_Interface)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                            
            END              
                  
           IF CHARINDEX('@n_CartonNo', @c_SQL) > 0 AND ISNULL(@n_CartonNo, 0) = 0 AND @n_continue IN(1,2)      
            BEGIN      
               SELECT @n_Continue = 3                                                                                                                                                                    
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                                  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid setup. Must specify carton no. Code:' +  RTRIM(@c_Code) +' Func:' + RTRIM(@c_FunctionID) + ' Type:' + RTRIM(@c_Type) +  ' Storer:' +RTRIM(@c_GetStorerkey)       
                                + ' (isp_Carrier_Middleware_Interface)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                            
            END               
                
           IF CHARINDEX('@c_MBOLKey', @c_SQL) > 0 AND ISNULL(@c_MBOLKey, '') = '' AND @n_continue IN(1,2)      
            BEGIN      
               SELECT @n_Continue = 3                                                                                                                                                                    
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                                  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid setup. Must specify Mbolkey. Code:' +  RTRIM(@c_Code) +' Func:' + RTRIM(@c_FunctionID) + ' Type:' + RTRIM(@c_Type) +  ' Storer:' +RTRIM(@c_GetStorerkey)       
                                + ' (isp_Carrier_Middleware_Interface)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                            
            END             
                
          IF ISNULL(@c_UDF01,'') = '' OR ISNULL(@c_UDF02,'') = ''      
            BEGIN      
               SELECT @n_Continue = 3                                                                                                                                                                    
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                                  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid setup. Must specify Tablename. Code:' +  RTRIM(@c_Code) +' Func:' + RTRIM(@c_FunctionID) + ' Type:' + RTRIM(@c_Type) +  ' Storer:' +RTRIM(@c_GetStorerkey)       
                                + ' (isp_Carrier_Middleware_Interface)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                            
            END                
                
          IF @n_continue IN(1,2)      
          BEGIN      
             IF @c_WSCourier = 'Y'      
                SET @c_TableName = @c_UDF01      
             ELSE      
                SET @c_TableName = @c_UDF02      
                                 
             INSERT INTO #TMP_Transmitlog_Work (key1, key2, key3)  --The SQL must select key1, key2 and key3      
                EXEC sp_ExecuteSql @c_SQL, N'@c_Storerkey NVARCHAR(15), @c_OrderKey NVARCHAR(10), @c_Mbolkey NVARCHAR(10), @c_FunctionID  NVARCHAR(10), @n_CartonNo INT, @n_Step INT,      
                                             @c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10), @c_Facility NVARCHAR(5)',      
                @c_Storerkey,      
                @c_Orderkey,      
                @c_Mbolkey,      
                @c_FunctionID,      
                @n_CartonNo,      
                @n_Step,      
                @c_Loadkey,      
                @c_Wavekey,      
                @c_Facility                         
            
               SELECT @n_err = @@ERROR        
                                
               IF @n_err <> 0                 
               BEGIN                                       
                  SELECT @n_Continue = 3                                                                                                                                                                    
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                                  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error execute SQL Condition. Code:' +  RTRIM(@c_Code) +' Func:' + RTRIM(@c_FunctionID) + ' Type:' + RTRIM(@c_Type) +  ' Storer:' +RTRIM(@c_GetStorerkey)       
                                   + ' (isp_Carrier_Middleware_Interface)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                                                                                                                             
 
    
           
             END        
             ELSE IF EXISTS(SELECT 1 FROM #TMP_Transmitlog_Work)      
             BEGIN              
                INSERT INTO #TMP_Transmitlog (TableName, Key1, Key2, Key3)      
                   SELECT @c_TableName, Key1, Key2, Key3      
                   FROM #TMP_Transmitlog_Work      
      
                  CLOSE CUR_TYPEDETAIL      
                  DEALLOCATE CUR_TYPEDETAIL                         
                GOTO NEXT_TYPE   --same storer, type, function id only need to meet any one line of the setup sort by code      
             END           
          END                               
                                            
            FETCH NEXT FROM CUR_TYPEDETAIL INTO @c_Code, @c_Notes, @c_UDF01, @c_UDF02             
         END      
         CLOSE CUR_TYPEDETAIL      
         DEALLOCATE CUR_TYPEDETAIL      
               
         NEXT_TYPE:      
                      
         FETCH NEXT FROM CUR_TYPE INTO @c_Type, @c_GetStorerkey                     
      END      
      CLOSE CUR_TYPE      
      DEALLOCATE CUR_TYPE                                          
    END      
        
   --Create transmitlog2 records       
   IF @n_continue IN(1,2) AND EXISTS(SELECT 1 FROM #TMP_Transmitlog)        
   BEGIN      
      DECLARE CUR_TRMLOG CURSOR LOCAL FAST_FORWARD READ_ONLY FOR             
         SELECT TableName, Key1, Key2, Key3      
         FROM #TMP_Transmitlog      
      
      OPEN CUR_TRMLOG                                                    
                   
      FETCH NEXT FROM CUR_TRMLOG INTO @c_TableName, @c_Key1, @c_Key2, @c_Key3      
                                                                 
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)                 
      BEGIN             
         EXEC ispGenTransmitLog2      
              @c_TableName      = @c_TableName,      
              @c_Key1           = @c_Key1,      
              @c_Key2           = @c_Key2,      
              @c_Key3           = @c_Key3,      
              @c_TransmitBatch  = '',      
              @b_Success       = @b_Success OUTPUT,      
              @n_err            = @n_err OUTPUT,      
              @c_errmsg         = @c_ErrMsg OUTPUT       
             
       IF @b_Success = 0 OR @n_err <> 0      
       BEGIN      
            SELECT @n_Continue = 3                                                                                                                                                                    
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                                  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Create Transmitlog2. TableName:' +  RTRIM(@c_TableName) +' Key1:' + RTRIM(@c_key1) + ' Key2:' + RTRIM(@c_Key2) +  ' Key3:' +RTRIM(@c_key3)       
                             + ' (isp_Carrier_Middleware_Interface)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                                                                                                                                   
 
             
        END     
        
             
        SELECT @c_TargetDB = ISNULL(RTRIM(TargetDB), '')     --JSM-148371 Start  
        FROM   QCmd_TransmitlogConfig WITH (NOLOCK)      
        WHERE  TableName =  @c_TableName    
        AND Storerkey = @c_Key3     
    
        SELECT @c_TransmitlogKey = TransmitlogKey     
        FROM TRANSMITLOG2 WITH (NOLOCK)     
        WHERE TABLENAME = @c_TableName     
        AND Key1 = @c_Key1    
        AND Key2 = @c_Key2    
        AND Key3 = @c_Key3     
        
        IF ISNULL(@c_TransmitlogKey,'') <> ''    
        BEGIN    
            SET @c_ExecStatements = N'EXEC ' + @c_TargetDB + '.' + @c_TargetSchema + '.isp_QCmd_WSTransmitLogInsertAlert '    
                                   + N'  @c_QCmdClass = '''' '    
                                   + N', @c_FrmTransmitlogKey = @c_TransmitlogKey '    
                                   + N', @c_ToTransmitlogKey = @c_TransmitlogKey '    
                                   + N', @b_Debug = @b_Debug '    
                                   + N', @b_Success = @b_Success OUTPUT '    
                                   + N', @n_Err =  @n_Err OUTPUT '    
                                   + N', @c_ErrMsg = @c_ErrMsg OUTPUT '    
                
            SET @c_ExecArguments = N' @c_TransmitlogKey  NVARCHAR(10)'    
                                   + N',@b_Debug           INT OUTPUT'    
                                   + N',@b_Success         INT OUTPUT'    
                                   + N',@n_Err             INT OUTPUT'    
                                   + N',@c_ErrMsg          NVARCHAR(255) OUTPUT'    
                
            EXEC sp_ExecuteSql @c_ExecStatements    
                               ,@c_ExecArguments    
                               ,@c_TransmitlogKey      
                               ,@b_Debug      OUTPUT    
                               ,@b_Success    OUTPUT    
                               ,@n_Err        OUTPUT    
                               ,@c_ErrMsg     OUTPUT    
        END                                                  --JSM-148371 End
                                      
         FETCH NEXT FROM CUR_TRMLOG INTO @c_TableName, @c_Key1, @c_Key2, @c_Key3      
      END      
      CLOSE CUR_TRMLOG      
      DEALLOCATE CUR_TRMLOG                  
   END      
           
EXIT_SP:              
      
   IF OBJECT_ID ('tempdb..#TMP_Transmitlog', 'U') IS NOT NULL      
      DROP TABLE #TMP_Transmitlog        
            
   IF OBJECT_ID ('tempdb..#TMP_Transmitlog_Work', 'U') IS NOT NULL      
      DROP TABLE #TMP_Transmitlog_Work              
         
   IF @n_Continue=3  -- Error Occured - Process And Return            
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_Carrier_Middleware_Interface'            
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012            
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
END -- Procedure

GO