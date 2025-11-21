SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store Procedure: isp_MoveTL3MBOLSet                                  */      
/* Creation Date:03-FEB-2020                                            */      
/* Copyright: IDS                                                       */      
/* Written by: LFL                                                      */      
/*                                                                      */      
/* Purpose: - To move archived table setup in codelkup back to live db. */      
/*                                                                      */      
/* Called By:                                                           */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Modifications:                                                       */      
/* Date         Author    Ver.  Purposes                                */   
/* Date         Author    Ver.  Purposes                                */  
/* 27-JAN-2022  CSCHONG   1.0    Devops Scripts Combine                 */ 
/* 22-JUL-2021  CSCHONG   1.1    WMS-10009 add in key3 parameter (CS01) */    
/************************************************************************/      
      
CREATE PROCEDURE [dbo].[isp_MoveTL3MBOLSet]      
     @c_SourceDB    NVARCHAR(30)      
   , @c_TargetDB    NVARCHAR(30)      
   , @c_TableSchema NVARCHAR(10)      
   , @c_TableName   NVARCHAR(50)      
   , @c_KeyColumn   NVARCHAR(50) -- OrderKey      
   , @c_DocKey      NVARCHAR(50)      
   , @c_key3        NVARCHAR(20) =''--Storerkey  
   , @b_Success     int           OUTPUT      
   , @n_err         int           OUTPUT      
   , @c_errmsg      NVARCHAR(250) OUTPUT      
   , @b_Debug       INT = 0   
AS      
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
DECLARE @c_SQL             NVARCHAR(MAX)      
      , @c_StorerKey       NVARCHAR(15)      
      , @c_Sku             NVARCHAR(20)      
      , @c_Lot             NVARCHAR(10)      
      , @c_Loc             NVARCHAR(10)      
      , @c_Id              NVARCHAR(18)      
      , @c_PackKey         NVARCHAR(10)      
      , @c_ValidFlag       NVARCHAR(1)      
      , @c_ArchiveCop      NVARCHAR(1)      
      , @n_DummyQty        INT      
      , @c_ExecArguments   NVARCHAR(MAX)      
      , @b_RecFound        INT      
      , @n_continue        int       
      , @c_mbolkey         NVARCHAR(50)      
      , @c_loadkey         NVARCHAR(20)      
      , @c_Pickslipno      NVARCHAR(20)      
      , @c_ContainerKey    NVARCHAR(20)      
      , @c_palletkey       NVARCHAR(30)      
      , @c_labelno         NVARCHAR(20)      
      , @n_StartTCnt       INT       
      , @c_ExecMSQL        NVARCHAR(MAX) 
      , @c_ExecSQL         NVARCHAR(MAX)    
      , @c_OrderLineNumber  NVARCHAR(10)      
      , @c_getOrderKey      NVARCHAR(50)      
      , @c_MbolLineNumber  NVARCHAR(10)      
      , @c_getmbolkey      NVARCHAR(50)      
      , @c_getloadkey      NVARCHAR(20)      
      , @c_LoadLineNumber  NVARCHAR(10)      
      , @c_GetPickslipno   NVARCHAR(20)      
      , @n_cartonno        INT      
      , @c_Getlabelno      NVARCHAR(20)      
      , @c_LabelLine       NVARCHAR(10)      
      , @n_PackSerialNoKey BIGINT      
      , @n_ContainerKey    NVARCHAR(20)        
      , @c_ContainerLineNumber NVARCHAR(20)      
      , @c_PalletLineNumber    NVARCHAR(20)      
      , @n_CTRowNo             INT      
      , @c_CTlabelno           NVARCHAR(20)      
      , @c_Trackingno          NVARCHAR(20)      
      , @c_addwho              NVARCHAR(50) 
      , @c_orderkey            NVARCHAR(20)   
      , @c_SerialNoKey         NVARCHAR(10)   
      , @c_chkstorerkey        NVARCHAR(20)      --CS01   
      , @c_Getstorerkey        NVARCHAR(20)      --CS01 
      , @c_CMBExists           NVARCHAR(1)       --CS01
      , @c_CDPLTKEYExists      NVARCHAR(1)       --CS01  
      , @c_CDPLTDETExists      NVARCHAR(1)       --CS01  
      , @c_CDUPCExists         NVARCHAR(1)       --CS01 
      , @c_PSNPSExists         NVARCHAR(1)       --CS01  
      , @c_chkCSQL             NVARCHAR(MAX)     --CS01
      , @c_pickdetailkey       NVARCHAR(20)      --CS01
      , @c_Getserialno         NVARCHAR(30)      --CS01  
      , @c_pickheaderkey       NVARCHAR(20)      --CS01
      , @c_SNTBLExists         NVARCHAR(1)       --CS01
      , @c_SNPDExists          NVARCHAR(1)       --CS01 
      , @c_SNPORDExists        NVARCHAR(1)       --CS01
      , @c_GetSN               NVARCHAR(30)      --CS01      
      
   SELECT @n_continue=1      
      
SET @c_ArchiveCop = NULL      
SET @n_DummyQty   = '0'      
      
SET @c_StorerKey = ''      
SET @c_Sku       = ''      
SET @c_Lot       = ''      
SET @c_Loc       = ''      
SET @c_Id        = ''      
      
SET @c_SQL = ''  
SET @c_chkstorerkey  = ''   --CS01

IF @b_Debug = 1
BEGIN
   SELECT 'MBOL' , @c_TableName '@c_TableName', @c_DocKey '@c_dockey'
END 


SET @c_SQL = N'SELECT  TOP 1 @c_chkstorerkey = ORDERS.Storerkey'  + CHAR(13) +        
                   'FROM ' +        
                   QUOTENAME(@c_SourceDB, '[') + '.dbo.ORDERS WITH (NOLOCK) ' + CHAR(13) +        
                   'WHERE mbolkey =  @c_DocKey  ' 
       
        SET @c_ExecArguments = N'@c_DocKey NVARCHAR(50), @c_chkstorerkey NVARCHAR(20) OUTPUT'        
       
        EXEC sp_executesql @c_SQL        
            , @c_ExecArguments        
            , @c_DocKey         
           -- , @c_key3      
            , @c_chkstorerkey OUTPUT        
       
         IF @b_debug = '1'        
         BEGIN        
            SELECT @c_SQL '@c_SQL'        
            SELECT @c_Storerkey ' @c_Storerkey'        
         END   

        IF ISNULL(@c_chkstorerkey,'') = ''
        BEGIN
             SELECT TOP 1 @c_chkstorerkey = OH.Storerkey
             FROM ORDERS OH WITH (NOLOCK)
             WHERE mbolkey =  @c_DocKey 
        END
 IF ISNULL(@c_chkstorerkey,'') <> '' 
 BEGIN       
       IF @c_key3 <> @c_chkstorerkey
       BEGIN
             SET @n_continue=3   
             SET @n_err = 700003        
             SELECT @c_errmsg = 'Storerkey not match (isp_MoveTL3MBOLSet)'
             GOTO QUIT  
       END 
END
ELSE
BEGIN
        SET @n_continue=1   
        --SET @n_err = 700003        
        --SELECT @c_errmsg = 'NO Data found (isp_MoveTL3MBOLSet)'
        GOTO QUIT  
END

MOVE_MBOL:     
BEGIN      
      
           EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'MBOL', 'mbolkey', @c_DocKey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
        
          IF @b_Success <> 1 AND @c_errmsg <> ''      
          BEGIN      
            SET @n_continue=3      
            GOTO QUIT      
          END       
END      
    
MOVE_MBOLDETAIL:        
BEGIN      
       
       SET @c_StorerKey = ''      
       SET @c_ExecSQL = ''      
         
      
     SET @c_ExecSQL=N' DECLARE CUR_MBDET CURSOR FAST_FORWARD READ_ONLY FOR'        
                 + ' SELECT DISTINCT MB.mbolkey,MB.mbollinenumber'          
                 + ' FROM ' + @c_SourceDB + '.dbo.MBOLDETAIL MB WITH (NOLOCK)'   
                 --+ ' JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = MB.Orderkey'        
                 + ' WHERE MB.mbolkey =  @c_DocKey '           
                 + ' ORDER BY MB.mbolkey,MB.mbollinenumber '                
        
   EXEC sp_executesql @c_ExecSQL,        
            N'@c_DocKey NVARCHAR(50)',         
              @c_DocKey       
         
   OPEN CUR_MBDET        
           
   FETCH NEXT FROM CUR_MBDET INTO @c_getmbolkey,@c_MbolLineNumber        
           
   WHILE @@FETCH_STATUS <> -1        
   BEGIN        
      SET @n_Continue = 1        
    
     IF EXISTS (SELECT 1 FROM MBOL WITH (NOLOCK) WHERE mbolkey = @c_getmbolkey)      
     BEGIN      
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'MBOLDETAIL', 'mbolkey', @c_getmbolkey,'mbollinenumber',@c_MbolLineNumber ,'','','','',       
                 @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
     END      
     
         IF @b_Success <> 1 AND @c_errmsg <> ''      
         BEGIN      
           SET @n_continue=3      
           GOTO QUIT      
         END      
      
   FETCH NEXT FROM CUR_MBDET INTO @c_getmbolkey,@c_MbolLineNumber          
   END        
        
   CLOSE CUR_MBDET      
   DEALLOCATE CUR_MBDET        
END  

MOVE_ORDERS:         
BEGIN      
  IF @b_Debug = '1'
  BEGIN

     SELECT 'MOVE ORDERS',@c_DocKey '@c_DocKey'
    
  END
   DECLARE CUR_ORDHDBYMBOL CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT MBD.Orderkey
   FROM MBOLDETAIL MBD WITH (NOLOCK)
   WHERE MBD.Mbolkey = @c_DocKey
   
    OPEN CUR_ORDHDBYMBOL          
             
   FETCH NEXT FROM CUR_ORDHDBYMBOL INTO @c_getOrderKey        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN 

   SET @c_ExecSQL = ''

   SET @c_ExecSQL=N' DECLARE CUR_ORDHD CURSOR FAST_FORWARD READ_ONLY FOR'          
                 + ' SELECT DISTINCT OH.Orderkey'          
                 + ' FROM ' + @c_SourceDB + '.dbo.ORDERS OH WITH (NOLOCK) '         
                 + ' WHERE OH.orderkey =  @c_getOrderKey '           
                 + ' ORDER BY OH.Orderkey '        
   
    EXEC sp_executesql @c_ExecSQL,          
                    N'@c_getOrderKey NVARCHAR(20)',           
                      @c_getOrderKey         
               
   OPEN CUR_ORDHD          
             
   FETCH NEXT FROM CUR_ORDHD INTO @c_orderkey        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN          
      SET @n_Continue = 1     
      
      EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'Orders', 'OrderKey', @c_orderkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
        
            IF @b_Success <> 1 AND @c_errmsg <> ''      
            BEGIN      
              SET @n_continue=3      
              GOTO QUIT      
            END 

   FETCH NEXT FROM CUR_ORDHD INTO @c_orderkey          
   END          
          
   CLOSE CUR_ORDHD          
   DEALLOCATE CUR_ORDHD 

FETCH NEXT FROM CUR_ORDHDBYMBOL INTO @c_getOrderKey          
END          
          
   CLOSE CUR_ORDHDBYMBOL          
   DEALLOCATE CUR_ORDHDBYMBOL 
        
END      
    
MOVE_ORDERDETAIL:         
BEGIN         
          
     SET @c_StorerKey = ''      
     SET @c_ExecSQL = ''      
      
     SET @c_ExecSQL=N' DECLARE CUR_MBORDDET CURSOR FAST_FORWARD READ_ONLY FOR'        
                 + ' SELECT DISTINCT OD.OrderKey,OD.Orderlinenumber'        
                 + ' FROM ORDERS OH WITH (NOLOCK) '         
                 + ' JOIN ' + @c_SourceDB + '.dbo.ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey'           
                 + ' WHERE OH.mbolkey =  @c_DocKey '           
                 + ' ORDER BY OD.Orderkey,OD.OrderLineNumber '          
        
   EXEC sp_executesql @c_ExecSQL,        
            N'@c_DocKey NVARCHAR(50)',         
              @c_DocKey       
         
   OPEN CUR_MBORDDET        
           
   FETCH NEXT FROM CUR_MBORDDET INTO @c_getOrderKey,@c_OrderLineNumber        
           
   WHILE @@FETCH_STATUS <> -1        
   BEGIN        
      SET @n_Continue = 1        
     
     IF EXISTS (SELECT 1 FROM Orders WITH (NOLOCK) WHERE OrderKey = @c_getOrderKey)      
     BEGIN      
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'ORDERDETAIL', 'OrderKey', @c_getOrderKey,'OrderLineNumber',@c_OrderLineNumber ,'','','','',       
                 @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
    END      
     
      IF @b_Success <> 1 AND @c_errmsg <> ''      
      BEGIN      
        SET @n_continue=3      
        GOTO QUIT      
      END      
      
   FETCH NEXT FROM CUR_MBORDDET INTO @c_getOrderKey,@c_OrderLineNumber        
   END        
        
   CLOSE CUR_MBORDDET        
   DEALLOCATE CUR_MBORDDET        
END     

MOVE_LOADPLAN:         
BEGIN      
     SET @c_ExecSQL = ''
 
     SET @c_ExecSQL=N' DECLARE CUR_LPMB CURSOR FAST_FORWARD READ_ONLY FOR'          
                  + ' SELECT DISTINCT LP.loadkey'          
                  + ' FROM ' + @c_SourceDB + '.dbo.LOADPLAN LP WITH (NOLOCK)'        
                  + ' JOIN ORDERS OH WITH (NOLOCK) ON OH.Loadkey = LP.Loadkey'        
                  + ' WHERE OH.mbolkey =  @c_DocKey '           
                  + ' ORDER BY LP.loadkey '                

                  EXEC sp_executesql @c_ExecSQL,          
                                   N'@c_DocKey NVARCHAR(50)',           
                                     @c_DocKey         
               
                  OPEN CUR_LPMB          
             
                  FETCH NEXT FROM CUR_LPMB INTO @c_loadkey        
             
                  WHILE @@FETCH_STATUS <> -1          
                  BEGIN   

                    EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'LOADPLAN', 'loadkey', @c_loadkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
      
                     IF @b_Success <> 1 AND @c_errmsg <> ''      
                     BEGIN      
                       SET @n_continue=3      
                       GOTO QUIT      
                     END      
         
   FETCH NEXT FROM  CUR_LPMB INTO @c_loadkey           
   END          
          
   CLOSE CUR_LPMB          
   DEALLOCATE CUR_LPMB         
      
END      
    
MOVE_LOADPLANDETAIL:      
BEGIN      
              
    SET @c_ExecSQL = ''
  
    SET @c_ExecSQL=N' DECLARE CUR_LPDET CURSOR FAST_FORWARD READ_ONLY FOR'        
                 + ' SELECT DISTINCT LD.loadkey,LD.LoadLineNumber'        
                 + ' FROM ' + @c_SourceDB + '.dbo.LOADPLANDETAIL LD WITH (NOLOCK)'        
                 + ' JOIN ORDERS OH WITH (NOLOCK) ON OH.Loadkey = LD.Loadkey AND OH.Orderkey = LD.Orderkey' 
                 + ' WHERE OH.mbolkey =  @c_DocKey    '         
                 + ' ORDER BY LD.loadkey,LD.LoadLineNumber '        
        
   EXEC sp_executesql @c_ExecSQL,        
            N'@c_DocKey    NVARCHAR(50)',         
              @c_DocKey          
         
   OPEN CUR_LPDET        
           
   FETCH NEXT FROM CUR_LPDET INTO @c_getloadkey,@c_LoadLineNumber        
           
   WHILE @@FETCH_STATUS <> -1        
   BEGIN        
      SET @n_Continue = 1        
      
     IF EXISTS (SELECT 1 FROM LOADPLAN WITH (NOLOCK) WHERE loadkey = @c_loadkey )      
     BEGIN      
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'LOADPLANDETAIL', 'loadkey', @c_getloadkey,'LoadLineNumber',@c_LoadLineNumber ,'','','','',       
                 @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
     END      
   --END      
      IF @b_Success <> 1 AND @c_errmsg <> ''      
      BEGIN      
        SET @n_continue=3      
        GOTO QUIT      
      END      
      
   FETCH NEXT FROM CUR_LPDET INTO @c_getloadkey,@c_LoadLineNumber          
   END        
        
   CLOSE CUR_LPDET        
   DEALLOCATE CUR_LPDET        
      
END          

MOVE_PICKDETAIL:  
BEGIN

  SET @c_ExecSQL = ''
 
  SET @c_ExecSQL=N' DECLARE CUR_PICKORDMB CURSOR FAST_FORWARD READ_ONLY FOR'          
                 + ' SELECT DISTINCT OH.Orderkey'          
                 + ' FROM ORDERS OH WITH (NOLOCK) '         
                 + ' WHERE OH.mbolkey =  @c_DocKey '           
                 + ' ORDER BY OH.Orderkey '        
   
    EXEC sp_executesql @c_ExecSQL,          
                    N'@c_DocKey NVARCHAR(50)',           
                      @c_DocKey         
               
   OPEN CUR_PICKORDMB          
             
   FETCH NEXT FROM CUR_PICKORDMB INTO @c_orderkey        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN          
      SET @n_Continue = 1  
      --PRINT 'chk move pickdetail'

      EXEC isp_ReTriggerTransmitLog_MovePickDetail @c_SourceDB, @c_TargetDB, 'dbo', 'PICKDETAIL', 'orderkey', @c_orderkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      

     
      IF @b_Success <> 1 AND @c_errmsg <> ''      
      BEGIN      
        SET @n_continue=3      
        GOTO QUIT      
      END  
   
   FETCH NEXT FROM CUR_PICKORDMB INTO @c_orderkey          
   END          
          
   CLOSE CUR_PICKORDMB          
   DEALLOCATE CUR_PICKORDMB     

END
    
MOVE_PICKHEADER:     
BEGIN      

   
  SET @c_ExecMSQL = ''
 
  SET @c_ExecMSQL=N' DECLARE CUR_PHMB CURSOR FAST_FORWARD READ_ONLY FOR'          
                + ' SELECT DISTINCT OH.orderkey'          
                + ' FROM ORDERS OH WITH (NOLOCK) '         
                + ' WHERE OH.mbolkey =  @c_DocKey '           
                + ' ORDER BY OH.orderkey '                

   EXEC sp_executesql @c_ExecMSQL,          
                N'@c_DocKey NVARCHAR(50)',           
                  @c_DocKey         
               
   OPEN CUR_PHMB          
             
   FETCH NEXT FROM CUR_PHMB INTO @c_Orderkey        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN   
               IF @b_Debug =2
               BEGIN
                  SELECT 'MOVE_PICKHEADER', @c_Orderkey '@c_Orderkey'
               END

               SET @c_loadkey = ''      
               SET @c_Pickslipno = ''    
               SET @c_pickheaderkey = ''   
               SET @c_ExecSQL = ''   
      
           --EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PICKHEADER', 'orderkey', @c_orderkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
      
           -- IF @b_Success <> 1 AND @c_errmsg <> ''      
           -- BEGIN      
           --   SET @n_continue=3      
           --   GOTO QUIT      
           -- END      

        SET @c_chkCSQL = ''  
      SET @c_chkCSQL = N'SELECT @c_pickheaderkey = PH.Pickheaderkey ' + CHAR(13) +  
                     ' FROM ' +  @c_SourceDB + '.dbo.PICKHEADER PH WITH (NOLOCK)  '  + CHAR(13) +  
                     ' WHERE PH.orderkey =  @c_Orderkey ' 
  
      SET @c_ExecArguments = N'@c_Orderkey NVARCHAR(20),@c_pickheaderkey NVARCHAR(20) OUTPUT'  
      EXEC sp_executesql @c_chkCSQL  
                       , @c_ExecArguments  
                       , @c_Orderkey
                       , @c_pickheaderkey  OUTPUT  
      
      

        IF ISNULL(@c_pickheaderkey,'') <>''
        BEGIN 
      
         --EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PICKHEADER', 'orderkey', @c_DocKey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
           EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PICKHEADER', 'Pickheaderkey', @c_pickheaderkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
      
         IF @b_Success <> 1 AND @c_errmsg <> ''      
         BEGIN      
           SET @n_continue=3      
           GOTO QUIT      
         END      
       END  
       ELSE
       BEGIN
      
                --SELECT @c_Pickslipno = Pickheaderkey      
                --FROM PICKHEADER WITH (NOLOCK)      
                --WHERE orderkey = @c_orderkey      
         

               SET @c_pickheaderkey = ''
               SELECT @c_loadkey = loadkey      
               FROM ORDERS (NOLOCK)      
               where OrderKey = @c_DocKey 

            SET @c_chkCSQL = ''  
            SET @c_chkCSQL = N'SELECT @c_pickheaderkey = PH.Pickheaderkey ' + CHAR(13) +  
                           ' FROM ' +  @c_SourceDB + '.dbo.PICKHEADER PH WITH (NOLOCK)  '  + CHAR(13) +  
                           ' WHERE PH.externorderkey =  @c_loadkey ' 
  
            SET @c_ExecArguments = N'@c_loadkey NVARCHAR(20),@c_pickheaderkey NVARCHAR(20) OUTPUT'  
            EXEC sp_executesql @c_chkCSQL  
                             , @c_ExecArguments  
                             , @c_loadkey
                             , @c_pickheaderkey  OUTPUT  
      
      

                    IF ISNULL(@c_pickheaderkey,'') <>''
                    BEGIN 
      
                     --EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PICKHEADER', 'orderkey', @c_DocKey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
                       EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PICKHEADER', 'Pickheaderkey', @c_pickheaderkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
      
                     IF @b_Success <> 1 AND @c_errmsg <> ''      
                     BEGIN      
                       SET @n_continue=3      
                       GOTO QUIT      
                     END      
                   END  

 

            --IF ISNULL(@c_Pickslipno,'') = ''      
            --BEGIN      
            --      SET @c_ExecSQL=N' DECLARE CUR_PHLoad CURSOR FAST_FORWARD READ_ONLY FOR'          
            --              + ' SELECT DISTINCT OH.loadkey'          
            --              + ' FROM ORDERS OH WITH (NOLOCK) '         
            --              + ' WHERE OH.orderkey =  @c_orderkey '           
            --              + ' ORDER BY OH.loadkey '                

            --EXEC sp_executesql @c_ExecSQL,          
            --                 N'@c_orderkey NVARCHAR(20)',           
            --                   @c_orderkey        
               
            --OPEN CUR_PHLoad          
             
            --FETCH NEXT FROM CUR_PHLoad INTO @c_loadkey        
             
            --WHILE @@FETCH_STATUS <> -1          
            --BEGIN          
            --   SET @n_Continue = 1        
           
            --    EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PICKHEADER', 'externorderkey', @c_loadkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug                
      
            --   IF @b_Success <> 1 AND @c_errmsg <> ''      
            --   BEGIN      
            --      SET @n_continue=3      
            --      GOTO QUIT      
            --   END      
           
            --FETCH NEXT FROM CUR_PHLoad INTO @c_loadkey          
            --END          
          
            --CLOSE CUR_PHLoad          
            --DEALLOCATE CUR_PHLoad         
         
        END      

   FETCH NEXT FROM CUR_PHMB INTO @c_Orderkey          
   END          
          
   CLOSE CUR_PHMB          
   DEALLOCATE CUR_PHMB     
         
END      
    
MOVE_PACKHEADER:    
BEGIN      
      SET @c_ExecSQL = ''


      SET @c_ExecSQL=N' DECLARE CUR_PIHMB CURSOR FAST_FORWARD READ_ONLY FOR'          
                                + ' SELECT DISTINCT OH.Orderkey'          
                                + ' FROM ORDERS OH WITH (NOLOCK) '         
                                + ' WHERE OH.mbolkey =  @c_DocKey '           
                                + ' ORDER BY OH.Orderkey '                

                  EXEC sp_executesql @c_ExecSQL,          
                                   N'@c_DocKey NVARCHAR(50)',           
                                     @c_DocKey         
               
                  OPEN CUR_PIHMB          
             
                  FETCH NEXT FROM CUR_PIHMB INTO @c_orderkey        
             
                  WHILE @@FETCH_STATUS <> -1          
                  BEGIN          
                        SET @n_Continue = 1    
                        SET @c_Pickslipno = ''
                        SET @c_loadkey = ''
                        SET @c_StorerKey = ''
               
                         SELECT @c_Pickslipno = Pickheaderkey  
                         FROM PICKHEADER WITH (NOLOCK)  
                         WHERE Orderkey = @c_Orderkey       
      
                         IF ISNULL(@c_Pickslipno,'') = ''  
                         BEGIN  
                              SELECT @c_loadkey = loadkey  
                                    ,@c_StorerKey = storerkey  
                              FROM ORDERS WITH (NOLOCK)  
                              WHERE Orderkey = @c_orderkey  
  
                            SELECT @c_Pickslipno = Pickheaderkey  
                            FROM PICKHEADER WITH (NOLOCK)  
                            WHERE ExternOrderkey = @c_loadkey  
  
                       END  
  
                           IF @c_Pickslipno <> ''  
                           BEGIN  
                                EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PACKHEADER', 'Pickslipno', @c_Pickslipno, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
                           END
        
                  FETCH NEXT FROM CUR_PIHMB INTO @c_orderkey          
                  END          
          
                  CLOSE CUR_PIHMB          
                  DEALLOCATE CUR_PIHMB       
END        
    
MOVE_PACKDETAIL:      
BEGIN    
    SET @c_ExecMSQL = ''

    SET @c_ExecMSQL=N' DECLARE CUR_PADBYMB CURSOR FAST_FORWARD READ_ONLY FOR'          
               + ' SELECT DISTINCT OH.Orderkey'          
               + ' FROM ORDERS OH WITH (NOLOCK) '         
               + ' WHERE OH.mbolkey =  @c_DocKey '           
               + ' ORDER BY OH.Orderkey '                

   EXEC sp_executesql @c_ExecMSQL,          
                     N'@c_DocKey NVARCHAR(50)',           
                        @c_DocKey         
               
   OPEN CUR_PADBYMB          
             
   FETCH NEXT FROM CUR_PADBYMB INTO @c_orderkey        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN   
      
   SET @c_loadkey = ''      
   SET @c_Pickslipno = ''
   SET @c_ExecSQL = ''      
      
   SELECT @c_Pickslipno = Pickheaderkey      
   FROM PICKHEADER WITH (NOLOCK)      
   WHERE Orderkey = @c_orderkey      
      
   IF ISNULL(@c_Pickslipno,'') = ''      
   BEGIN      
     SELECT @c_loadkey = loadkey      
           ,@c_StorerKey = storerkey      
      FROM ORDERS WITH (NOLOCK)      
      WHERE Orderkey = @c_orderkey      
      
    SELECT @c_Pickslipno = Pickheaderkey      
    FROM PICKHEADER WITH (NOLOCK)      
    WHERE ExternOrderkey = @c_loadkey      
      
   END      
      
     SET @c_ExecSQL=N' DECLARE CUR_PADDET CURSOR FAST_FORWARD READ_ONLY FOR'        
                 + ' SELECT DISTINCT Pickslipno,cartonno,labelno,LabelLine'        
                 + ' FROM ' + @c_SourceDB + '.dbo.PACKDETAIL PD WITH (NOLOCK)'         
                 + ' WHERE PD.Pickslipno =  @c_Pickslipno '         
                 + ' ORDER BY Pickslipno,cartonno,labelno,LabelLine '        
        
   EXEC sp_executesql @c_ExecSQL,        
            N'@c_Pickslipno NVARCHAR(20)',         
              @c_Pickslipno       
         
   OPEN CUR_PADDET        
           
   FETCH NEXT FROM CUR_PADDET INTO @c_GetPickslipno,@n_cartonno,@c_Getlabelno , @c_LabelLine      
           
   WHILE @@FETCH_STATUS <> -1        
   BEGIN        
      SET @n_Continue = 1          
      IF ISNULL(@c_GetPickslipno,'') <> ''      
      BEGIN      
         EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'PACKDETAIL', 'pickslipno', @c_GetPickslipno,'cartonno',@n_cartonno ,      
                'labelno',@c_Getlabelno,'labelline',@c_LabelLine,@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
      END      
     
      IF @b_Success <> 1 AND @c_errmsg <> ''      
      BEGIN      
        SET @n_continue=3      
        GOTO QUIT      
      END      
      
      FETCH NEXT FROM CUR_PADDET INTO @c_GetPickslipno,@n_cartonno,@c_Getlabelno , @c_LabelLine         
      END        
        
      CLOSE CUR_PADDET        
      DEALLOCATE CUR_PADDET        
      
  FETCH NEXT FROM CUR_PADBYMB INTO @c_orderkey          
  END          
          
  CLOSE CUR_PADBYMB          
  DEALLOCATE CUR_PADBYMB      
END      
    
MOVE_PACKINFO:     
BEGIN 
   SET @c_ExecMSQL = ''


   SET @c_ExecMSQL=N' DECLARE CUR_PIFBYMB CURSOR FAST_FORWARD READ_ONLY FOR'          
               + ' SELECT DISTINCT OH.Orderkey'          
               + ' FROM ORDERS OH WITH (NOLOCK) '         
               + ' WHERE OH.mbolkey =  @c_DocKey '           
               + ' ORDER BY OH.Orderkey '                

   EXEC sp_executesql @c_ExecMSQL,          
                     N'@c_DocKey NVARCHAR(50)',           
                        @c_DocKey         
               
   OPEN CUR_PIFBYMB          
             
   FETCH NEXT FROM CUR_PIFBYMB INTO @c_orderkey        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN     
      
      SET @c_loadkey = ''      
      SET @c_Pickslipno = ''      
      SET @c_ExecSQL = ''       
      
   SELECT @c_Pickslipno = Pickheaderkey      
   FROM PICKHEADER WITH (NOLOCK)      
   WHERE Orderkey = @c_orderkey      
   
   IF ISNULL(@c_Pickslipno,'') = ''      
   BEGIN      
     SELECT @c_loadkey = loadkey      
           ,@c_StorerKey = storerkey      
      FROM ORDERS WITH (NOLOCK)      
      WHERE Orderkey = @c_orderkey      
      
    SELECT @c_Pickslipno = Pickheaderkey      
    FROM PICKHEADER WITH (NOLOCK)      
    WHERE ExternOrderkey = @c_loadkey      
      
   END      
           
           SET @c_ExecSQL=N' DECLARE CUR_PIF CURSOR FAST_FORWARD READ_ONLY FOR'        
                       + ' SELECT DISTINCT Pickslipno,cartonno'        
                       + ' FROM ' + @c_SourceDB + '.dbo.PACKINFO PIF WITH (NOLOCK)'         
                       + ' WHERE PIF.Pickslipno =  @c_Pickslipno '         
                       + ' ORDER BY Pickslipno,cartonno '        
        
         EXEC sp_executesql @c_ExecSQL,        
                  N'@c_Pickslipno NVARCHAR(20)',         
                    @c_Pickslipno       
         
         OPEN CUR_PIF        
           
         FETCH NEXT FROM CUR_PIF INTO @c_GetPickslipno,@n_cartonno      
           
         WHILE @@FETCH_STATUS <> -1        
         BEGIN        
            SET @n_Continue = 1            
           IF ISNULL(@c_GetPickslipno,'') <> ''      
           BEGIN      
               EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'PACKINFO', 'pickslipno', @c_GetPickslipno,'cartonno',@n_cartonno ,      
                      '','','','',@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
          END      
 
         IF @b_Success <> 1 AND @c_errmsg <> ''      
         BEGIN      
           SET @n_continue=3      
           GOTO QUIT      
         END      
      
         FETCH NEXT FROM CUR_PIF INTO @c_GetPickslipno,@n_cartonno       
         END        
        
         CLOSE CUR_PIF        
         DEALLOCATE CUR_PIF      
      
 FETCH NEXT FROM CUR_PIFBYMB INTO @c_orderkey          
 END          
          
 CLOSE CUR_PIFBYMB          
 DEALLOCATE CUR_PIFBYMB       
END      
    
MOVE_PICKINGINFO:      
BEGIN     

    SET @c_ExecSQL = ''
 
    SET @c_ExecSQL=N' DECLARE CUR_PCIFBYMB CURSOR FAST_FORWARD READ_ONLY FOR'          
               + ' SELECT DISTINCT OH.Orderkey'          
               + ' FROM ORDERS OH WITH (NOLOCK) '         
               + ' WHERE OH.mbolkey =  @c_DocKey '           
               + ' ORDER BY OH.Orderkey '                

   EXEC sp_executesql @c_ExecSQL,          
                     N'@c_DocKey NVARCHAR(50)',           
                        @c_DocKey         
               
   OPEN CUR_PCIFBYMB          
             
   FETCH NEXT FROM CUR_PCIFBYMB INTO @c_orderkey        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN    
         SET @c_loadkey = ''      
         SET @c_Pickslipno = ''      
      
         SELECT @c_Pickslipno = Pickheaderkey      
         FROM PICKHEADER WITH (NOLOCK)      
         WHERE Orderkey = @c_orderkey      
      
         IF ISNULL(@c_Pickslipno,'') = ''      
         BEGIN      
         SELECT @c_loadkey = loadkey      
            ,@c_StorerKey = storerkey      
         FROM ORDERS WITH (NOLOCK)      
         WHERE Orderkey = @c_orderkey      
      
         SELECT @c_Pickslipno = Pickheaderkey      
         FROM PICKHEADER WITH (NOLOCK)      
         WHERE ExternOrderkey = @c_loadkey      
      
         END      
      
         IF @c_Pickslipno <> ''      
         BEGIN      
            EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PICKINGINFO', 'Pickslipno', @c_Pickslipno, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
         END 

        
 FETCH NEXT FROM CUR_PCIFBYMB INTO @c_orderkey          
 END          
          
 CLOSE CUR_PCIFBYMB          
 DEALLOCATE CUR_PCIFBYMB       
END      
    
MOVE_PACKSERIALNO:      
BEGIN     
    SET @c_ExecMSQL = ''

    SET @c_ExecMSQL=N' DECLARE CUR_PASNBYMB CURSOR FAST_FORWARD READ_ONLY FOR'          
                                + ' SELECT DISTINCT OH.Orderkey'          
                                + ' FROM ORDERS OH WITH (NOLOCK) '         
                                + ' WHERE OH.mbolkey =  @c_DocKey '           
                                + ' ORDER BY OH.Orderkey '                

                  EXEC sp_executesql @c_ExecMSQL,          
                                   N'@c_DocKey NVARCHAR(50)',           
                                     @c_DocKey         
               
                  OPEN CUR_PASNBYMB          
             
                  FETCH NEXT FROM CUR_PASNBYMB INTO @c_orderkey        
             
                  WHILE @@FETCH_STATUS <> -1          
                  BEGIN     

                            SET @c_PSNPSExists = '0'
      
                           SET @c_loadkey = ''      
                           SET @c_Pickslipno = ''      
                           SET @c_ExecSQL = ''      
      
                        SELECT @c_Pickslipno = Pickheaderkey      
                        FROM PICKHEADER WITH (NOLOCK)      
                        WHERE Orderkey = @c_orderkey      
      
                        IF ISNULL(@c_Pickslipno,'') = ''      
                        BEGIN      
                          SELECT @c_loadkey = loadkey      
                                ,@c_StorerKey = storerkey      
                           FROM ORDERS WITH (NOLOCK)      
                           WHERE Orderkey = @c_orderkey      
      
                         SELECT @c_Pickslipno = Pickheaderkey      
                         FROM PICKHEADER WITH (NOLOCK)      
                         WHERE ExternOrderkey = @c_loadkey      
      
                        END 

                     SET @c_chkCSQL = ''  
                     SET @c_chkCSQL = N'SELECT @c_PSNPSExists = ''1'' ' + CHAR(13) +  
                                    ' FROM ' +  @c_SourceDB + '.dbo.PACKSERIALNO PAS WITH (NOLOCK)  '  + CHAR(13) +  
                                    ' WHERE PAS.Pickslipno =  @c_Pickslipno ' 
  
                     SET @c_ExecArguments = N'@c_Pickslipno NVARCHAR(20),@c_PSNPSExists NVARCHAR(1) OUTPUT'  
                     EXEC sp_executesql @c_chkCSQL  
                                       , @c_ExecArguments  
                                       , @c_Pickslipno  
                                       , @c_PSNPSExists  OUTPUT  
      
                        IF @c_PSNPSExists = '1'
                        BEGIN     
      
                              SET @c_ExecSQL=N' DECLARE CUR_PAS CURSOR FAST_FORWARD READ_ONLY FOR'        
                                               + ' SELECT DISTINCT PAS.PackSerialNoKey,PAS.serialno,PAS.storerkey,PAS.pickdetailkey'        
                                               + ' FROM ' + @c_SourceDB + '.dbo.PACKSERIALNO PAS WITH (NOLOCK)'         
                                               + ' WHERE PAS.Pickslipno =  @c_Pickslipno '         
                                               + ' ORDER BY PAS.PackSerialNoKey '          
        
                                 EXEC sp_executesql @c_ExecSQL,        
                                          N'@c_Pickslipno NVARCHAR(20)',         
                                            @c_Pickslipno   
                         END  
                         ELSE
                         BEGIN
                            SET @c_ExecSQL=N' DECLARE CUR_PAS CURSOR FAST_FORWARD READ_ONLY FOR'        
                                + ' SELECT DISTINCT PAS.PackSerialNoKey,PAS.serialno,PAS.storerkey,PAS.pickdetailkey'        
                                + ' FROM ' + @c_SourceDB + '.dbo.PACKSERIALNO PAS WITH (NOLOCK)'    
                                + ' JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Pickdetailkey = PAS.Pickdetailkey '     
                                + ' WHERE PD.Orderkey =  @c_orderkey '         
                                + ' ORDER BY PAS.PackSerialNoKey '        
        
                                    EXEC sp_executesql @c_ExecSQL,        
                                    N'@c_orderkey NVARCHAR(20)',         
                                      @c_orderkey      
                         END  
      
         
                                 OPEN CUR_PAS        
           
                                 FETCH NEXT FROM CUR_PAS INTO @n_PackSerialNoKey ,@c_Getserialno,@c_Getstorerkey,@c_pickdetailkey      --CS01     
           
                                 WHILE @@FETCH_STATUS <> -1        
                                 BEGIN        
                        
                                 SET @n_Continue = 1        
                                   IF ISNULL(@n_PackSerialNoKey,'') <> ''      
                                   BEGIN 

                                      --SELECT @n_PackSerialNoKey '@n_PackSerialNoKey'
    
                                       EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'PACKSERIALNO', 'PackSerialNoKey', @n_PackSerialNoKey,'storerkey',@c_Getstorerkey ,      
                                              'PickDetailKey',@c_pickdetailkey,'SerialNo', @c_Getserialno,@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug     
                                   END      
          
      
                                 IF @b_Success <> 1 AND @c_errmsg <> ''      
                                 BEGIN      
                                   SET @n_continue=3      
                                   GOTO QUIT      
                                 END      
      
                                 FETCH NEXT FROM CUR_PAS INTO @n_PackSerialNoKey  ,@c_Getserialno,@c_Getstorerkey,@c_pickdetailkey      --CS01     
                                 END        
        
                                 CLOSE CUR_PAS        
                                 DEALLOCATE CUR_PAS      
      
   FETCH NEXT FROM CUR_PASNBYMB INTO @c_orderkey          
   END          
          
   CLOSE CUR_PASNBYMB          
   DEALLOCATE CUR_PASNBYMB      
END      
      
MOVE_CONTAINER:       
BEGIN      

    SET @c_ExecMSQL = ''

   SET @c_mbolkey = ''      
   SET @c_ExecSQL = ''      
   SET @c_loadkey = ''     


      SET @c_CMBExists = '0' 
      SET @c_CDPLTKEYExists = '0'
      SET @c_CDUPCExists = '0'
      SET @c_CDPLTDETExists = '0'
      SET @c_chkCSQL = ''  

      SET @c_chkCSQL = N'SELECT @c_CMBExists = ''1'' ' + CHAR(13) +  
                    'FROM ' +  @c_SourceDB + '.dbo.CONTAINER C WITH (NOLOCK)  '  + CHAR(13) +  
                    'WHERE C.OtherReference =  @c_DocKey  '  
  
      SET @c_ExecArguments = N'@c_DocKey NVARCHAR(50),@c_CMBExists NVARCHAR(1) OUTPUT'  
      EXEC sp_executesql @c_chkCSQL  
                       , @c_ExecArguments  
                       , @c_DocKey  
                       , @c_CMBExists  OUTPUT  


    -- SELECT @c_CMBExists '@c_CMBExists'

     IF @c_CMBExists ='1'
     BEGIN
        SET @c_ExecSQL=N' DECLARE CUR_CONT CURSOR FAST_FORWARD READ_ONLY FOR'   
                        + ' SELECT DISTINCT C.ContainerKey'        
                        + ' FROM ' + @c_SourceDB + '.dbo.CONTAINER C WITH (NOLOCK)'         
                        + ' WHERE C.OtherReference =  @c_DocKey '    

        
                     EXEC sp_executesql @c_ExecSQL,        
                              N'@c_DocKey NVARCHAR(50) ',         
                                @c_DocKey      
         
                     OPEN CUR_CONT        
           
                     FETCH NEXT FROM CUR_CONT INTO @c_ContainerKey      
           
                     WHILE @@FETCH_STATUS <> -1        
                     BEGIN        
                        SET @n_Continue = 1        
                       IF ISNULL(@c_ContainerKey,'') <> ''      
                       BEGIN      
                           EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'CONTAINER', 'ContainerKey', @c_ContainerKey,'','' ,      
                                  '','','','',@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
                      END      
    
                     IF @b_Success <> 1 AND @c_errmsg <> ''      
                     BEGIN      
                       SET @n_continue=3      
                       GOTO QUIT      
                     END      
      
                     FETCH NEXT FROM CUR_CONT INTO @c_ContainerKey      
                     END        
        
                     CLOSE CUR_CONT        
                     DEALLOCATE CUR_CONT      
    END
    ELSE IF @c_CMBExists ='0' AND @c_CDPLTKEYExists = '0' AND @c_CDUPCExists = '0' AND @c_CDPLTDETExists = '0'
    BEGIN
         SET @c_chkCSQL = ''  
         SET @c_chkCSQL = N' SELECT @c_CDPLTDETExists = ''1'' ' + CHAR(13) +  
                        ' FROM ' + @c_SourceDB + '.dbo.CONTAINER C WITH (NOLOCK)  '  + CHAR(13) +  
                        ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON CD.ContainerKey = C.ContainerKey '   + CHAR(13) +  
                       -- ' JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON CD.Palletkey = PL.Palletkey '                     + CHAR(13) +  
                        ' JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK) ON CD.PalletKey = PLD.PalletKey '        + CHAR(13) +      
                        ' WHERE C.OtherReference =  @c_DocKey  '  


                SET @c_ExecArguments = N'@c_DocKey NVARCHAR(50),@c_CDPLTDETExists NVARCHAR(1) OUTPUT'  
                EXEC sp_executesql @c_chkCSQL  
                       ,  @c_ExecArguments  
                       ,  @c_DocKey
                       ,  @c_CDPLTDETExists  OUTPUT  


            IF @c_CDPLTDETExists ='1'
            BEGIN
                  SET @c_ExecSQL=N' DECLARE CUR_CONT CURSOR FAST_FORWARD READ_ONLY FOR'   
                                 + 'SELECT DISTINCT C.ContainerKey '        
                                 + ' FROM ' + @c_SourceDB + '.dob.CONTAINER C WITH (NOLOCK)'         
                                 + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON CD.ContainerKey = C.ContainerKey '   
                                 + ' JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK) ON CD.PalletKey = PLD.PalletKey '    
                                 + ' WHERE C.OtherReference =  @c_DocKey '        
                                 + ' ORDER BY C.ContainerKey, CD.ContainerLineNumber '   

                  
                     EXEC sp_executesql @c_ExecSQL,        
                              N'@c_DocKey NVARCHAR(50)',         
                                @c_DocKey     
         
                     OPEN CUR_CONT        
           
                     FETCH NEXT FROM CUR_CONT INTO @c_ContainerKey      
           
                     WHILE @@FETCH_STATUS <> -1        
                     BEGIN        
                        SET @n_Continue = 1        
                       IF ISNULL(@c_ContainerKey,'') <> ''      
                       BEGIN      
                           EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'CONTAINER', 'ContainerKey', @c_ContainerKey,'','' ,      
                                  '','','','',@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
                      END      
    
                     IF @b_Success <> 1 AND @c_errmsg <> ''      
                     BEGIN      
                       SET @n_continue=3      
                       GOTO QUIT      
                     END      
      
                     FETCH NEXT FROM CUR_CONT INTO @c_ContainerKey      
                     END        
        
                     CLOSE CUR_CONT        
                     DEALLOCATE CUR_CONT   
            END
    END
    ELSE IF @c_CMBExists ='0' AND @c_CDPLTKEYExists = '0' AND @c_CDPLTKEYExists = '0' AND @c_CDUPCExists ='0'
    BEGIN

    SET @c_ExecMSQL=N' DECLARE CUR_CONTMB CURSOR FAST_FORWARD READ_ONLY FOR'          
                  + ' SELECT DISTINCT OH.Orderkey'          
                  + ' FROM ORDERS OH WITH (NOLOCK) '         
                  + ' WHERE OH.mbolkey =  @c_DocKey '           
                  + ' ORDER BY OH.Orderkey '                

                  EXEC sp_executesql @c_ExecMSQL,          
                                   N'@c_DocKey NVARCHAR(50)',           
                                     @c_DocKey         
               
                  OPEN CUR_CONTMB          
             
                  FETCH NEXT FROM CUR_CONTMB INTO @c_orderkey        
             
                  WHILE @@FETCH_STATUS <> -1          
                  BEGIN                      
      
                        SELECT @c_mbolkey = mbolkey      
                              ,@c_StorerKey = storerkey      
                              ,@c_loadkey = loadkey      
                        FROM ORDERS WITH (NOLOCK)      
                        WHERE Orderkey = @c_orderkey      
      
                      SET @c_Pickslipno = ''      
      
                     SELECT @c_Pickslipno = Pickslipno      
                     FROM PACKHEADER WITH (NOLOCK)      
                     WHERE Orderkey = @c_orderkey      
      
                     IF ISNULL(@c_Pickslipno,'') = ''      
                     BEGIN      
                       SELECT @c_loadkey = loadkey      
                             ,@c_StorerKey = storerkey      
                        FROM ORDERS WITH (NOLOCK)      
                        WHERE Orderkey = @c_orderkey      
      
                      SELECT @c_Pickslipno = Pickslipno      
                      FROM PACKHEADER WITH (NOLOCK)      
                      WHERE loadkey = @c_loadkey      
      
                     END                  
      
                      --SET @c_ExecSQL=N' DECLARE CUR_CONT CURSOR FAST_FORWARD READ_ONLY FOR'        
                      --             + ' SELECT DISTINCT C.ContainerKey '        
                      --             + ' FROM PACKHEADER PH (NOLOCK) '      
                      --             + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +      
                      --             + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON (PD.LabelNo = CD.Palletkey OR PD.UPC = CD.Palletkey) '      
                      --             + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '        
                      --             + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON CD.Palletkey = PL.Palletkey '        
                      --             + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK) ON PL.PalletKey = PLD.PalletKey '         
                      --             + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '         
                      --             + ' UNION' + CHAR(13) +      
                      --             + ' SELECT DISTINCT C.ContainerKey'        
                      --             + ' FROM ' + @c_SourceDB + '.dbo.CONTAINER C WITH (NOLOCK)'         
                      --             + ' WHERE C.OtherReference =  @c_mbolkey '        
                      --             + ' UNION' + CHAR(13) +        
                      --             + ' SELECT DISTINCT C.ContainerKey '        
                      --             + ' FROM PACKHEADER PH (NOLOCK) '      
                      --             + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +      
                      --             + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON PD.UPC = CD.Palletkey '      
                      --             + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '        
                      --             + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON CD.Palletkey = PL.Palletkey '        
                      --             + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK)  ON PL.PalletKey = PLD.PalletKey '         
                      --             + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '        
                      --             + ' UNION' + CHAR(13) +        
                      --             + ' SELECT DISTINCT C.ContainerKey '        
                      --             + ' FROM PACKHEADER PH (NOLOCK) '      
                      --             + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +      
                      --             + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK) ON PD.LabelNo = PLD.CaseId AND PD.StorerKey = PLD.StorerKey '         
                      --             + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON PLD.Palletkey = PL.Palletkey '                         
                      --             + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON PLD.Palletkey = CD.Palletkey '      
                      --             + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '        
                      --             + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '        
                      --             + ' ORDER BY C.ContainerKey '         
         
      SET @c_chkCSQL = ''  
      SET @c_chkCSQL = N'SELECT @c_CDPLTKEYExists = ''1'' ' + CHAR(13) +  
                        ' FROM PACKHEADER PH (NOLOCK) '    + CHAR(13) +   
                        ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +      
                        ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON (PD.LabelNo = CD.Palletkey ) '    + CHAR(13) +   
                        ' JOIN ' + @c_SourceDB + '.dbo.CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '        + CHAR(13) + 
                        ' WHERE PH.PickSlipNo  =  @c_Pickslipno '          
                        
  
      SET @c_ExecArguments = N'@c_Pickslipno NVARCHAR(20),@c_CDPLTKEYExists NVARCHAR(1) OUTPUT'  
      EXEC sp_executesql @c_chkCSQL  
                       , @c_ExecArguments  
                       , @c_Pickslipno  
                       , @c_CDPLTKEYExists  OUTPUT  

        IF @c_CDPLTKEYExists ='1'
        BEGIN
        SET @c_ExecSQL=N' DECLARE CUR_CONT CURSOR FAST_FORWARD READ_ONLY FOR'   
                        + ' SELECT DISTINCT C.ContainerKey'        
                        + ' FROM PACKHEADER PH (NOLOCK) '      
                        + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +      
                        + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON (PD.LabelNo = CD.Palletkey) '      
                        + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '                
                        + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '              
        END
        ELSE IF @c_CMBExists ='0' AND @c_CDPLTKEYExists = '0' AND @c_CDUPCExists = '0'
        BEGIN

        SET @c_chkCSQL = ''  
        SET @c_chkCSQL = N'SELECT @c_CDUPCExists = ''1'' ' + CHAR(13) +  
                        ' FROM PACKHEADER PH (NOLOCK) '    + CHAR(13) +   
                        ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +      
                        ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON (PD.UPC = CD.Palletkey ) '    + CHAR(13) +   
                        ' JOIN ' + @c_SourceDB + '.dbo.CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '        + CHAR(13) + 
                        ' WHERE PH.PickSlipNo  =  @c_Pickslipno '          
  
       SET @c_ExecArguments = N'@c_Pickslipno NVARCHAR(20),@c_CDUPCExists NVARCHAR(1) OUTPUT'  
       EXEC sp_executesql @c_chkCSQL  
                       ,  @c_ExecArguments  
                       ,  @c_Pickslipno  
                       ,  @c_CDUPCExists  OUTPUT  

        --SELECT @c_CDUPCExists '@c_CDUPCExists'

        IF @c_CDUPCExists ='1'
        BEGIN
        SET @c_ExecSQL=N' DECLARE CUR_CONT CURSOR FAST_FORWARD READ_ONLY FOR'   
                        + ' SELECT DISTINCT C.ContainerKey'        
                        + ' FROM PACKHEADER PH (NOLOCK) '      
                        + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +      
                        + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON (PD.UPC = CD.Palletkey) '      
                        + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '                
                        + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '              
         END

    END  
    
 
         IF (@c_CMBExists ='1' OR @c_CDPLTKEYExists = '1' OR @c_CDUPCExists = '1' OR @c_CDPLTDETExists='1') AND @c_ExecSQL <> ''
         BEGIN 
                     EXEC sp_executesql @c_ExecSQL,        
                              N'@c_Pickslipno NVARCHAR(20) , @c_mbolkey NVARCHAR(20)',         
                                @c_Pickslipno,@c_mbolkey       
         
                     OPEN CUR_CONT        
           
                     FETCH NEXT FROM CUR_CONT INTO @c_ContainerKey      
           
                     WHILE @@FETCH_STATUS <> -1        
                     BEGIN        
                        SET @n_Continue = 1        
                       IF ISNULL(@c_ContainerKey,'') <> ''      
                       BEGIN      
                           EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'CONTAINER', 'ContainerKey', @c_ContainerKey,'','' ,      
                                  '','','','',@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
                      END      
    
                     IF @b_Success <> 1 AND @c_errmsg <> ''      
                     BEGIN      
                       SET @n_continue=3      
                       GOTO QUIT      
                     END      
      
                     FETCH NEXT FROM CUR_CONT INTO @c_ContainerKey      
                     END        
        
                     CLOSE CUR_CONT        
                     DEALLOCATE CUR_CONT      
             END
       
   FETCH NEXT FROM CUR_CONTMB INTO @c_orderkey          
   END          
          
   CLOSE CUR_CONTMB          
   DEALLOCATE CUR_CONTMB  
      
  END  

 END    

    
MOVE_CONTAINERDETAIL:    
BEGIN      

      SET @c_CMBExists = '0' 
      SET @c_CDPLTKEYExists = '0'
      SET @c_CDUPCExists = '0'
      SET @c_CDPLTDETExists = '0'
      SET @c_chkCSQL = ''  
      SET @c_chkCSQL = N' SELECT @c_CMBExists = ''1'' ' + CHAR(13) +  
                        ' FROM dbo.CONTAINER C WITH (NOLOCK)  '  + CHAR(13) +  
                        ' WHERE C.OtherReference =  @c_DocKey  '  
  
      SET @c_ExecArguments = N'@c_DocKey  NVARCHAR(50),@c_CMBExists NVARCHAR(1) OUTPUT'  
      EXEC sp_executesql @c_chkCSQL  
                       , @c_ExecArguments  
                       , @c_DocKey   
                       , @c_CMBExists  OUTPUT  


    -- SELECT @c_CMBExists '@c_CMBExists'

     IF @c_CMBExists ='1'
     BEGIN
        SET @c_ExecSQL=N' DECLARE CUR_CONDET CURSOR FAST_FORWARD READ_ONLY FOR '   
                        + ' SELECT DISTINCT C.ContainerKey , CD.ContainerLineNumber'        
                        + ' FROM CONTAINER C WITH (NOLOCK)'         
                        + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON CD.ContainerKey = C.ContainerKey '      
                        + ' WHERE C.OtherReference =  @c_DocKey '        
                        + ' ORDER BY C.ContainerKey, CD.ContainerLineNumber '  
          
                        EXEC sp_executesql @c_ExecSQL,        
                        N'@c_DocKey  NVARCHAR(50)',         
                          @c_DocKey      
         
               OPEN CUR_CONDET        
           
               FETCH NEXT FROM CUR_CONDET INTO @c_ContainerKey, @c_ContainerLineNumber      
           
               WHILE @@FETCH_STATUS <> -1        
               BEGIN        
                  SET @n_Continue = 1  
                       EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'CONTAINERDETAIL', 'ContainerKey', @c_ContainerKey,'ContainerLineNumber',@c_ContainerLineNumber ,      
                            '','','','',@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
     
                     IF @b_Success <> 1 AND @c_errmsg <> ''      
                     BEGIN      
                       SET @n_continue=3      
                       GOTO QUIT      
                     END      
      
               FETCH NEXT FROM CUR_CONDET INTO @c_ContainerKey, @c_ContainerLineNumber      
               END        
        
               CLOSE CUR_CONDET        
               DEALLOCATE CUR_CONDET 


    END
  ELSE IF @c_CMBExists ='0' AND @c_CDPLTKEYExists = '0' AND @c_CDUPCExists = '0' AND @c_CDPLTDETExists = '0'
  BEGIN
         SET @c_chkCSQL = ''  
         SET @c_chkCSQL = N' SELECT @c_CDPLTDETExists = ''1'' ' + CHAR(13) +  
                        ' FROM dbo.CONTAINER C WITH (NOLOCK)  '  + CHAR(13) +  
                        ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON CD.ContainerKey = C.ContainerKey '   + CHAR(13) +  
                       -- ' JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON CD.Palletkey = PL.Palletkey '                     + CHAR(13) +  
                        ' JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK) ON CD.PalletKey = PLD.PalletKey '        + CHAR(13) +      
                        ' WHERE C.OtherReference =  @c_dockey  '  


                SET @c_ExecArguments = N'@c_dockey NVARCHAR(50),@c_CDPLTDETExists NVARCHAR(1) OUTPUT'  
                EXEC sp_executesql @c_chkCSQL  
                       ,  @c_ExecArguments  
                       ,  @c_DocKey
                       ,  @c_CDPLTDETExists  OUTPUT  


            IF @c_CDPLTDETExists ='1'
            BEGIN
               SET @c_ExecSQL=N' DECLARE CUR_CONDET CURSOR FAST_FORWARD READ_ONLY FOR'   
                                 + 'SELECT DISTINCT C.ContainerKey , CD.ContainerLineNumber '        
                                 + ' FROM CONTAINER C WITH (NOLOCK)'         
                                 + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON CD.ContainerKey = C.ContainerKey '   
                                 + ' JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK) ON CD.PalletKey = PLD.PalletKey '    
                                 + ' WHERE C.OtherReference =  @c_dockey '        
                                 + ' ORDER BY C.ContainerKey, CD.ContainerLineNumber ' 

                  EXEC sp_executesql @c_ExecSQL,        
                       N'@c_dockey NVARCHAR(50)',         
                        @c_dockey    

               OPEN CUR_CONDET        
           
               FETCH NEXT FROM CUR_CONDET INTO @c_ContainerKey, @c_ContainerLineNumber      
           
               WHILE @@FETCH_STATUS <> -1        
               BEGIN        
                  SET @n_Continue = 1  
                       EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'CONTAINERDETAIL', 'ContainerKey', @c_ContainerKey,'ContainerLineNumber',@c_ContainerLineNumber ,      
                            '','','','',@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
     
                     IF @b_Success <> 1 AND @c_errmsg <> ''      
                     BEGIN      
                       SET @n_continue=3      
                       GOTO QUIT      
                     END      
      
               FETCH NEXT FROM CUR_CONDET INTO @c_ContainerKey, @c_ContainerLineNumber      
               END        
        
               CLOSE CUR_CONDET        
               DEALLOCATE CUR_CONDET 
            END

  END
  ELSE IF @c_CMBExists ='0' AND @c_CDPLTKEYExists = '0' AND @c_CDPLTKEYExists = '0' AND @c_CDUPCExists ='0'
  BEGIN
    SET @c_ExecMSQL = ''
    SET @c_ExecMSQL=N' DECLARE CUR_CONTDETMB CURSOR FAST_FORWARD READ_ONLY FOR'          
                  + ' SELECT DISTINCT OH.Orderkey'          
                  + ' FROM ORDERS OH WITH (NOLOCK) '         
                  + ' WHERE OH.mbolkey =  @c_DocKey '           
                  + ' ORDER BY OH.Orderkey '                

                  EXEC sp_executesql @c_ExecMSQL,          
                                   N'@c_DocKey NVARCHAR(50)',           
                                     @c_DocKey         
               
                  OPEN CUR_CONTDETMB          
             
                  FETCH NEXT FROM CUR_CONTDETMB INTO @c_orderkey        
             
                  WHILE @@FETCH_STATUS <> -1          
                  BEGIN       

                  SET @c_mbolkey = ''      
                  SET @c_ExecSQL = ''      
                  SET @c_loadkey = ''      
      
                  SELECT @c_mbolkey = mbolkey      
                        ,@c_StorerKey = storerkey      
                        ,@c_loadkey = loadkey      
                  FROM ORDERS WITH (NOLOCK)      
                  WHERE Orderkey = @c_orderkey      
      
                 SET @c_Pickslipno = ''      
      
               SELECT @c_Pickslipno = Pickslipno      
               FROM PACKHEADER WITH (NOLOCK)      
               WHERE Orderkey = @c_orderkey      
      
               IF ISNULL(@c_Pickslipno,'') = ''      
               BEGIN      
                 SELECT @c_loadkey = loadkey      
                       ,@c_StorerKey = storerkey      
                  FROM ORDERS WITH (NOLOCK)      
                  WHERE Orderkey = @c_orderkey      
      
                SELECT @c_Pickslipno = Pickslipno      
                FROM PACKHEADER WITH (NOLOCK)      
                WHERE loadkey = @c_loadkey      
      
               END           
      
                      --SET @c_ExecSQL=N' DECLARE CUR_CONDET CURSOR FAST_FORWARD READ_ONLY FOR'        
                      --       + ' SELECT DISTINCT C.ContainerKey , CD.ContainerLineNumber '        
                      --       + ' FROM PACKHEADER PH (NOLOCK) '      
                      --       + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +      
                      --       + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON (PD.LabelNo = CD.Palletkey OR PD.UPC = CD.Palletkey) '      
                      --       + ' JOIN CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '        
                      --       + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON CD.Palletkey = PL.Palletkey '        
                      --       + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK) ON PL.PalletKey = PLD.PalletKey '         
                      --       + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '         
                      --       + ' UNION' + CHAR(13) +      
                      --       + ' SELECT DISTINCT C.ContainerKey , CD.ContainerLineNumber'        
                      --       + ' FROM CONTAINER C WITH (NOLOCK)'         
                      --       + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON CD.ContainerKey = C.ContainerKey '      
                      --       + ' WHERE C.OtherReference =  @c_mbolkey '        
                      --       + ' UNION' + CHAR(13) +        
                      --       + ' SELECT DISTINCT C.ContainerKey, CD.ContainerLineNumber '        
                      --       + ' FROM PACKHEADER PH (NOLOCK) '      
                      --       + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +      
                      --       + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON PD.UPC = CD.Palletkey '      
                      --       + ' JOIN CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '        
                      --       + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON CD.Palletkey = PL.Palletkey '        
                      --       + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK)  ON PL.PalletKey = PLD.PalletKey '         
                      --       + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '        
                      --       + ' UNION' + CHAR(13) +        
                      --       + ' SELECT DISTINCT C.ContainerKey, CD.ContainerLineNumber '        
                      --       + ' FROM PACKHEADER PH (NOLOCK) '      
                      --       + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +      
                      --       + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK) ON PD.LabelNo = PLD.CaseId AND PD.StorerKey = PLD.StorerKey '         
                      --       + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON PLD.Palletkey = PL.Palletkey '                         
                      --       + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON PLD.Palletkey = CD.Palletkey '      
                      --       + ' JOIN dbo.CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '        
                      --       + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '        
                      --       + ' ORDER BY C.ContainerKey, CD.ContainerLineNumber '     


             IF @c_CMBExists ='0' AND @c_CDPLTKEYExists = '0'
             BEGIN

                  SET @c_chkCSQL = ''  
                  SET @c_chkCSQL = N'SELECT @c_CDPLTKEYExists = ''1'' ' + CHAR(13) +  
                                    ' FROM PACKHEADER PH (NOLOCK) '    + CHAR(13) +   
                                    ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +      
                                    ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON (PD.LabelNo = CD.Palletkey ) '    + CHAR(13) +   
                                    ' JOIN CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '        + CHAR(13) + 
                                    ' WHERE PH.PickSlipNo  =  @c_Pickslipno '          
  
                  SET @c_ExecArguments = N'@c_Pickslipno NVARCHAR(20),@c_CDPLTKEYExists NVARCHAR(1) OUTPUT'  
                  EXEC sp_executesql @c_chkCSQL  
                                   , @c_ExecArguments  
                                   , @c_Pickslipno  
                                   , @c_CDPLTKEYExists  OUTPUT  

                  -- SELECT @c_CDPLTKEYExists '@c_CDPLTKEYExists'

                    IF @c_CDPLTKEYExists ='1'
                    BEGIN
                    SET @c_ExecSQL=N' DECLARE CUR_CONDET CURSOR FAST_FORWARD READ_ONLY FOR '   
                                    + 'SELECT DISTINCT C.ContainerKey , CD.ContainerLineNumber '        
                                    + ' FROM PACKHEADER PH (NOLOCK) '      
                                    + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13)      
                                    + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON (PD.LabelNo = CD.Palletkey) '      
                                    + ' JOIN CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '               
                                    + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '     
                                    + ' ORDER BY C.ContainerKey, CD.ContainerLineNumber '                    
                     END

       

                END
                ELSE IF @c_CMBExists ='0' AND @c_CDPLTKEYExists = '0' AND @c_CDUPCExists = '0'
                BEGIN

                    SET @c_chkCSQL = ''  
                    SET @c_chkCSQL = N'SELECT @c_CDUPCExists = ''1'' ' + CHAR(13) +  
                                    ' FROM PACKHEADER PH (NOLOCK) '    + CHAR(13) +   
                                    ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +      
                                    ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON (PD.UPC = CD.Palletkey ) '    + CHAR(13) +   
                                    ' JOIN CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '        + CHAR(13) + 
                                    ' WHERE PH.PickSlipNo  =  @c_Pickslipno '          

  
                   SET @c_ExecArguments = N'@c_Pickslipno NVARCHAR(20),@c_CDUPCExists NVARCHAR(1) OUTPUT'  
                   EXEC sp_executesql @c_chkCSQL  
                                   ,  @c_ExecArguments  
                                   ,  @c_Pickslipno  
                                   ,  @c_CDUPCExists  OUTPUT  

                    --SELECT @c_CDUPCExists '@c_CDUPCExists'

                    IF @c_CDUPCExists ='1'
                    BEGIN
                    SET @c_ExecSQL=N' DECLARE CUR_CONDET CURSOR FAST_FORWARD READ_ONLY FOR'   
                                    + 'SELECT DISTINCT C.ContainerKey , CD.ContainerLineNumber '        
                                    + ' FROM PACKHEADER PH (NOLOCK) '      
                                    + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +      
                                    + ' JOIN ' + @c_SourceDB + '.dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON (PD.UPC = CD.Palletkey) '      
                                    + ' JOIN CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '               
                                    + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '    
                                    + ' ORDER BY C.ContainerKey, CD.ContainerLineNumber '       
                     END

                END     
              IF (@c_CMBExists ='1' OR @c_CDPLTKEYExists = '1' OR @c_CDUPCExists = '1' OR @c_CDPLTDETExists='1') AND @c_ExecSQL <> ''
              BEGIN
                     EXEC sp_executesql @c_ExecSQL,        
                        N'@c_Pickslipno NVARCHAR(20) ,@c_mbolkey NVARCHAR(20)',         
                          @c_Pickslipno ,@c_mbolkey       
         
               OPEN CUR_CONDET        
           
               FETCH NEXT FROM CUR_CONDET INTO @c_ContainerKey, @c_ContainerLineNumber      
           
               WHILE @@FETCH_STATUS <> -1        
               BEGIN        
                  SET @n_Continue = 1        
      
                     EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'CONTAINERDETAIL', 'ContainerKey', @c_ContainerKey,'ContainerLineNumber',@c_ContainerLineNumber ,      
                            '','','','',@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
     
                     IF @b_Success <> 1 AND @c_errmsg <> ''      
                     BEGIN      
                       SET @n_continue=3      
                       GOTO QUIT      
                     END      
      
               FETCH NEXT FROM CUR_CONDET INTO @c_ContainerKey, @c_ContainerLineNumber      
               END        
        
               CLOSE CUR_CONDET        
               DEALLOCATE CUR_CONDET 
      END
   FETCH NEXT FROM CUR_CONTDETMB INTO @c_orderkey          
   END          
          
   CLOSE CUR_CONTDETMB          
   DEALLOCATE CUR_CONTDETMB      
      
  END  
END   

MOVE_PALLETDETAIL:       
BEGIN      
 SET @c_ExecMSQL = ''

 SET @c_ExecMSQL=N' DECLARE CUR_PLTDETMB CURSOR FAST_FORWARD READ_ONLY FOR'          
                  + ' SELECT DISTINCT OH.Orderkey'          
                  + ' FROM ORDERS OH WITH (NOLOCK) '         
                  + ' WHERE OH.mbolkey =  @c_DocKey '           
                  + ' ORDER BY OH.Orderkey '                

                  EXEC sp_executesql @c_ExecMSQL,          
                                   N'@c_DocKey NVARCHAR(50)',           
                                     @c_DocKey         
               
                  OPEN CUR_PLTDETMB          
             
                  FETCH NEXT FROM CUR_PLTDETMB INTO @c_orderkey        
             
                  WHILE @@FETCH_STATUS <> -1          
                  BEGIN 
               
                     SET @c_mbolkey = ''      
                     SET @c_ExecSQL = ''      
                     SET @c_loadkey = ''      
      
                     SELECT @c_mbolkey = mbolkey      
                           ,@c_StorerKey = storerkey      
                           ,@c_loadkey = loadkey      
                     FROM ORDERS WITH (NOLOCK)      
                     WHERE Orderkey = @c_orderkey      
      
                     SET @c_Pickslipno = ''      
      
                  SELECT @c_Pickslipno = Pickslipno      
                  FROM PACKHEADER WITH (NOLOCK)      
                  WHERE Orderkey = @c_orderkey      
      
                  IF ISNULL(@c_Pickslipno,'') = ''      
                  BEGIN      
                     SELECT @c_loadkey = loadkey      
                           ,@c_StorerKey = storerkey      
                     FROM ORDERS WITH (NOLOCK)      
                     WHERE Orderkey = @c_orderkey      
      
                   SELECT @c_Pickslipno = Pickslipno      
                   FROM PACKHEADER WITH (NOLOCK)      
                   WHERE loadkey = @c_loadkey      
      
                  END      
        
      
                         --SET @c_ExecSQL=N' DECLARE CUR_PALDET CURSOR FAST_FORWARD READ_ONLY FOR'        
                         --       + ' SELECT DISTINCT PL.Palletkey,PLD.PalletLineNumber '        
                         --       + ' FROM PACKHEADER PH (NOLOCK) '      
                         --       + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +      
                         --       + ' JOIN CONTAINERDETAIL CD WITH (NOLOCK) ON (PD.LabelNo = CD.Palletkey OR PD.UPC = CD.Palletkey) '      
                         --       + ' JOIN CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '        
                         --       + ' LEFT JOIN dbo.PALLET PL (NOLOCK) ON CD.Palletkey = PL.Palletkey '        
                         --       + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK) ON PL.PalletKey = PLD.PalletKey '         
                         --       + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '         
                         --       + ' UNION' + CHAR(13) +      
                         --       + ' SELECT DISTINCT PL.Palletkey ,PLD.PalletLineNumber'        
                         --       + ' FROM PACKHEADER PH (NOLOCK) '      
                         --       + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +      
                         --       + ' JOIN CONTAINERDETAIL CD WITH (NOLOCK) ON PD.UPC = CD.Palletkey '      
                         --       + ' JOIN CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '        
                         --       + ' LEFT JOIN PALLET PL (NOLOCK) ON CD.Palletkey = PL.Palletkey '        
                         --       + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK)  ON PL.PalletKey = PLD.PalletKey '         
                         --       + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '        
                         --       + ' UNION' + CHAR(13) +        
                         --       + ' SELECT DISTINCT PL.Palletkey ,PLD.PalletLineNumber '        
                         --       + ' FROM PACKHEADER PH (NOLOCK) '      
                         --       + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +      
                         --       + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK) ON PD.LabelNo = PLD.CaseId AND PD.StorerKey = PLD.StorerKey '         
                         --       + ' LEFT JOIN PALLET PL (NOLOCK) ON PLD.Palletkey = PL.Palletkey '                         
                         --       + ' JOIN CONTAINERDETAIL CD WITH (NOLOCK) ON PLD.Palletkey = CD.Palletkey '      
                         --       + ' JOIN dbo.CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '        
                         --       + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '        
                         --       + ' ORDER BY PL.Palletkey '        

                         SET @c_ExecSQL=N' DECLARE CUR_PALDET CURSOR FAST_FORWARD READ_ONLY FOR'        
                                      + ' SELECT DISTINCT PLD.Palletkey,PLD.PalletLineNumber '        
                                      + ' FROM PACKHEADER PH (NOLOCK) '      
                                      + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +       
                                      + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK) ON PD.labelno = PLD.caseid AND PLD.storerkey = PD.storerkey '        
                                     -- + ' LEFT JOIN dbo.PALLET PL (NOLOCK) ON PLD.Palletkey = PL.Palletkey '                               
                                      + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '                
                                      + ' ORDER BY PLD.Palletkey,PLD.PalletLineNumber '         
               
            
                     EXEC sp_executesql @c_ExecSQL,        
                           N'@c_Pickslipno NVARCHAR(20) ',         
                             @c_Pickslipno        
         
                  OPEN CUR_PALDET        
           
                  FETCH NEXT FROM CUR_PALDET INTO @c_Palletkey, @c_PalletLineNumber      
           
                  WHILE @@FETCH_STATUS <> -1        
                  BEGIN        
                     SET @n_Continue = 1        
                    IF ISNULL(@c_Palletkey,'') <> '' AND ISNULL(@c_PalletLineNumber,'') <> ''      
                    BEGIN      
                        EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'PALLETDETAIL', 'Palletkey', @c_palletkey,'PalletLineNumber',@c_PalletLineNumber ,      
                               '','','','',@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
                   END      
            
                  IF @b_Success <> 1 AND @c_errmsg <> ''      
                  BEGIN      
                    SET @n_continue=3      
                    GOTO QUIT      
                  END      
      
                  FETCH NEXT FROM CUR_PALDET INTO @c_Palletkey, @c_PalletLineNumber      
                  END        
        
                  CLOSE CUR_PALDET        
                  DEALLOCATE CUR_PALDET      
      
   FETCH NEXT FROM CUR_PLTDETMB INTO @c_orderkey          
   END          
          
   CLOSE CUR_PLTDETMB          
   DEALLOCATE CUR_PLTDETMB     
      
END   
    
MOVE_PALLET:      
BEGIN      
     SET @c_ExecMSQL = ''
     SET @c_ExecMSQL=N' DECLARE CUR_PLTMB CURSOR FAST_FORWARD READ_ONLY FOR'          
                  + ' SELECT DISTINCT OH.Orderkey'          
                  + ' FROM ORDERS OH WITH (NOLOCK) '         
                  + ' WHERE OH.mbolkey =  @c_DocKey '           
                  + ' ORDER BY OH.Orderkey '                

                  EXEC sp_executesql @c_ExecMSQL,          
                                   N'@c_DocKey NVARCHAR(50)',           
                                     @c_DocKey         
               
                  OPEN CUR_PLTMB          
             
                  FETCH NEXT FROM CUR_PLTMB INTO @c_orderkey        
             
                  WHILE @@FETCH_STATUS <> -1          
                  BEGIN    
   
                        SET @c_mbolkey = ''      
                        SET @c_ExecSQL = ''      
                        SET @c_loadkey = ''      
      
                        SELECT @c_mbolkey = mbolkey      
                              ,@c_StorerKey = storerkey      
                              ,@c_loadkey = loadkey      
                        FROM ORDERS WITH (NOLOCK)      
                        WHERE Orderkey = @c_orderkey      
      
                       SET @c_Pickslipno = ''      
      
                     SELECT @c_Pickslipno = Pickslipno      
                     FROM PACKHEADER WITH (NOLOCK)      
                     WHERE Orderkey = @c_orderkey      
      
                     IF ISNULL(@c_Pickslipno,'') = ''      
                     BEGIN      
                       SELECT @c_loadkey = loadkey      
                             ,@c_StorerKey = storerkey      
                        FROM ORDERS WITH (NOLOCK)      
                        WHERE Orderkey = @c_orderkey      
      
                      SELECT @c_Pickslipno = Pickslipno      
                      FROM PACKHEADER WITH (NOLOCK)      
                      WHERE loadkey = @c_loadkey      
      
                     END             
      
                            --SET @c_ExecSQL=N' DECLARE CUR_PLT CURSOR FAST_FORWARD READ_ONLY FOR'        
                            --       + ' SELECT DISTINCT PL.Palletkey '        
                            --       + ' FROM PACKHEADER PH (NOLOCK) '      
                            --       + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +      
                            --       + ' JOIN CONTAINERDETAIL CD WITH (NOLOCK) ON (PD.LabelNo = CD.Palletkey OR PD.UPC = CD.Palletkey) '      
                            --       + ' JOIN CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '        
                            --       + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON CD.Palletkey = PL.Palletkey '        
                            --       + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK) ON PL.PalletKey = PLD.PalletKey '         
                            --       + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '         
                            --       + ' UNION' + CHAR(13) +      
                            --       + ' SELECT DISTINCT PL.Palletkey '        
                            --       + ' FROM PACKHEADER PH (NOLOCK) '      
                            --       + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +      
                            --       + ' JOIN CONTAINERDETAIL CD WITH (NOLOCK) ON PD.UPC = CD.Palletkey '      
                            --       + ' JOIN CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '        
                            --       + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON CD.Palletkey = PL.Palletkey '        
                            --       + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK)  ON PL.PalletKey = PLD.PalletKey '         
                            --       + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '        
                            --       + ' UNION' + CHAR(13) +        
                            --       + ' SELECT DISTINCT PL.Palletkey '        
                            --       + ' FROM PACKHEADER PH (NOLOCK) '      
                            --       + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +      
                            --       + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK) ON PD.LabelNo = PLD.CaseId AND PD.StorerKey = PLD.StorerKey '         
                            --       + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON PLD.Palletkey = PL.Palletkey '                         
                            --       + ' JOIN CONTAINERDETAIL CD WITH (NOLOCK) ON PLD.Palletkey = CD.Palletkey '      
                            --       + ' JOIN dbo.CONTAINER C WITH (NOLOCK) ON CD.Containerkey = C.ContainerKey '        
                            --       + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '        
                            --       + ' ORDER BY PL.Palletkey '         
            
                       SET @c_ExecSQL=N' DECLARE CUR_PLT CURSOR FAST_FORWARD READ_ONLY FOR'        
                                         + ' SELECT DISTINCT PL.Palletkey '        
                                         + ' FROM PACKHEADER PH (NOLOCK) '      
                                         + ' JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo ' + CHAR(13) +              
                                        -- + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLETDETAIL PLD WITH (NOLOCK) ON PLD.caseid = PD.labelno AND PLD.storerkey = PD.storerkey ' 
                                         + ' LEFT JOIN dbo.PALLETDETAIL PLD WITH (NOLOCK) ON PLD.caseid = PD.labelno AND PLD.storerkey = PD.storerkey ' 
                                         + ' LEFT JOIN ' + @c_SourceDB + '.dbo.PALLET PL (NOLOCK) ON PLD.Palletkey = PL.Palletkey '                              
                                         + ' WHERE PH.PickSlipNo  =  @c_Pickslipno '               
                                         + ' ORDER BY PL.Palletkey '       

                        EXEC sp_executesql @c_ExecSQL,        
                              N'@c_Pickslipno NVARCHAR(20) ',         
                                @c_Pickslipno       
         
                     OPEN CUR_PLT        
           
                     FETCH NEXT FROM CUR_PLT INTO @c_palletkey      
           
                     WHILE @@FETCH_STATUS <> -1        
                     BEGIN        
                     IF ISNULL(@c_palletkey,'') <> ''      
                     BEGIN      
                        EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'PALLET', 'PALLETKEY', @c_palletkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
                     END   

                       IF @b_Success <> 1 AND @c_errmsg <> ''      
                        BEGIN      
                          SET @n_continue=3      
                          GOTO QUIT      
                        END      
      
                     FETCH NEXT FROM CUR_PLT INTO @c_palletkey      
                     END        
        
                     CLOSE CUR_PLT        
                     DEALLOCATE CUR_PLT 

   FETCH NEXT FROM CUR_PLTMB INTO @c_orderkey          
   END          
          
   CLOSE CUR_PLTMB          
   DEALLOCATE CUR_PLTMB        
      
END      
    
    
    
MOVE_CARTONTRACK:      
BEGIN   
    SET @c_ExecMSQL = ''

     SET @c_ExecMSQL=N' DECLARE CUR_CTNTRKMB CURSOR FAST_FORWARD READ_ONLY FOR'          
                  + ' SELECT DISTINCT OH.Orderkey'          
                  + ' FROM ORDERS OH WITH (NOLOCK) '         
                  + ' WHERE OH.mbolkey =  @c_DocKey '           
                  + ' ORDER BY OH.Orderkey '                

                  EXEC sp_executesql @c_ExecMSQL,          
                                   N'@c_DocKey NVARCHAR(50)',           
                                     @c_DocKey         
               
                  OPEN CUR_CTNTRKMB          
             
                  FETCH NEXT FROM CUR_CTNTRKMB INTO @c_orderkey        
             
                  WHILE @@FETCH_STATUS <> -1          
                  BEGIN    
      
                SET @c_labelno = ''      
      
                SET @c_loadkey = ''      
                SET @c_Pickslipno = ''      
                SET @c_ExecSQL = ''      
      
               SELECT @c_Pickslipno = Pickslipno      
               FROM PACKHEADER WITH (NOLOCK)      
               WHERE Orderkey = @c_orderkey      
      
               IF ISNULL(@c_Pickslipno,'') = ''      
               BEGIN      
                 SELECT @c_loadkey = loadkey      
                       ,@c_StorerKey = storerkey      
                  FROM ORDERS WITH (NOLOCK)      
                  WHERE Orderkey = @c_orderkey      
      
                SELECT @c_Pickslipno = Pickslipno      
                FROM PACKHEADER WITH (NOLOCK)      
                WHERE loadkey = @c_loadkey      
      
               END      
      
                  SELECT @c_labelno = labelno      
                  FROM PACKDETAIL WITH (NOLOCK)      
                  WHERE pickslipno = @c_Pickslipno      
      
                  IF ISNULL(@c_labelno,'') = ''      
                  BEGIN      
                     SET @c_labelno = @c_DocKey      
                  END      
      
                SET @c_ExecSQL=N' DECLARE CUR_CTK CURSOR FAST_FORWARD READ_ONLY FOR'        
                             + ' SELECT DISTINCT CT.RowRef,CT.labelno,CT.trackingno,CT.Addwho'        
                             + ' FROM ' + @c_SourceDB + '.dbo.CARTONTRACK CT WITH (NOLOCK)'         
                             + ' JOIN dbo.Packdetail PD WITH (NOLOCK) ON PD.labelno = CT.labelno' 
                             --+ ' WHERE CT.labelno =  @c_labelno OR CT.labelno = @c_DocKey'   
                             + ' WHERE PD.Pickslipno = @c_Pickslipno'       
                             + ' ORDER BY CT.RowRef '        
        
               EXEC sp_executesql @c_ExecSQL,        
                        N'@c_labelno NVARCHAR(20),@c_DocKey NVARCHAR(50),@c_Pickslipno NVARCHAR(20)',         
                          @c_labelno, @c_DocKey , @c_Pickslipno      
         
               OPEN CUR_CTK        
           
               FETCH NEXT FROM CUR_CTK INTO @n_CTRowNo,@c_CTlabelno,@c_trackingno,@c_Addwho      
           
               WHILE @@FETCH_STATUS <> -1        
               BEGIN        
      
                     SET @n_Continue = 1          
                     EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'CARTONTRACK', 'RowRef', @n_CTRowNo,'labelno',@c_CTlabelno ,      
                            'trackingno',@c_trackingno,'Addwho',@c_Addwho,@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
   
                     IF @b_Success <> 1 AND @c_errmsg <> ''      
                     BEGIN      
                       SET @n_continue=3      
                       GOTO QUIT      
                     END      
      
               FETCH NEXT FROM CUR_CTK INTO @n_CTRowNo,@c_CTlabelno,@c_trackingno,@c_Addwho      
               END        
        
               CLOSE CUR_CTK        
               DEALLOCATE CUR_CTK       
      
   FETCH NEXT FROM CUR_CTNTRKMB INTO @c_orderkey          
   END          
          
   CLOSE CUR_CTNTRKMB          
   DEALLOCATE CUR_CTNTRKMB        

MOVE_ORDERINFO:         
BEGIN      
  IF @b_Debug = '1'
  BEGIN

     SELECT 'MOVE ORDERINFO',@c_DocKey '@c_DocKey'
    
  END
  
   DECLARE CUR_ORDIFBYMBOL CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT MBD.Orderkey
   FROM MBOLDETAIL MBD WITH (NOLOCK)
   WHERE MBD.Mbolkey = @c_DocKey
   ORDER BY MBD.Orderkey

    OPEN CUR_ORDIFBYMBOL          
             
   FETCH NEXT FROM CUR_ORDIFBYMBOL INTO @c_getOrderKey        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN   


   SET @c_ExecSQL = ''

   SET @c_ExecSQL=N' DECLARE CUR_ORDIF CURSOR FAST_FORWARD READ_ONLY FOR'          
                 + ' SELECT DISTINCT OIF.Orderkey' 
                 + ' FROM ' + @c_SourceDB + '.dbo.ORDERINFO OIF WITH (NOLOCK) '         
                 + ' WHERE OIF.orderkey =  @c_getOrderKey '           
                 + ' ORDER BY OIF.Orderkey '        
   
    EXEC sp_executesql @c_ExecSQL,          
                    N' @c_getOrderKey NVARCHAR(50)',           
                      @c_getOrderKey         
               
   OPEN CUR_ORDIF          
             
   FETCH NEXT FROM CUR_ORDIF INTO @c_orderkey        
             
   WHILE @@FETCH_STATUS <> -1          
   BEGIN          
      SET @n_Continue = 1     

      
      EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'ORDERINFO', 'OrderKey', @c_orderkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug      
        
            IF @b_Success <> 1 AND @c_errmsg <> ''      
            BEGIN      
              SET @n_continue=3      
              GOTO QUIT      
            END 

   FETCH NEXT FROM CUR_ORDIF INTO @c_orderkey          
   END          
          
   CLOSE CUR_ORDIF          
   DEALLOCATE CUR_ORDIF      


 FETCH NEXT FROM CUR_ORDIFBYMBOL INTO @c_getOrderKey          
   END          
          
   CLOSE CUR_ORDIFBYMBOL          
   DEALLOCATE CUR_ORDIFBYMBOL     
END         

MOVE_SERIALNO:      
BEGIN     
    SET @c_ExecMSQL = ''

    SET @c_ExecMSQL=N' DECLARE CUR_SNBYMB CURSOR FAST_FORWARD READ_ONLY FOR'          
                                + ' SELECT DISTINCT OH.Orderkey'          
                                + ' FROM ORDERS OH WITH (NOLOCK) '         
                                + ' WHERE OH.mbolkey =  @c_DocKey '           
                                + ' ORDER BY OH.Orderkey '                

                  EXEC sp_executesql @c_ExecMSQL,          
                                   N'@c_DocKey NVARCHAR(50)',           
                                     @c_DocKey         
               
                  OPEN CUR_SNBYMB          
             
                  FETCH NEXT FROM CUR_SNBYMB INTO @c_orderkey        
             
                  WHILE @@FETCH_STATUS <> -1          
                  BEGIN     
      
                           SET @c_loadkey = ''      
                           SET @c_Pickslipno = ''      
                           SET @c_ExecSQL = ''   
                           SET @c_SNTBLExists = '0'
                           SET @c_SNPDExists = '0' 
                           SET @c_SNPORDExists = '0'
                           
      
                        SELECT @c_Pickslipno = Pickheaderkey      
                        FROM PICKHEADER WITH (NOLOCK)      
                        WHERE Orderkey = @c_orderkey      
      
                        IF ISNULL(@c_Pickslipno,'') = ''      
                        BEGIN      
                          SELECT @c_loadkey = loadkey      
                                ,@c_StorerKey = storerkey      
                           FROM ORDERS WITH (NOLOCK)      
                           WHERE Orderkey = @c_orderkey      
      
                         SELECT @c_Pickslipno = Pickheaderkey      
                         FROM PICKHEADER WITH (NOLOCK)      
                         WHERE ExternOrderkey = @c_loadkey      
      
                        END     

                        SET @c_chkCSQL = ''  
                        SET @c_chkCSQL = N'SELECT @c_SNTBLExists = ''1'' ' + CHAR(13) +  
                                    ' FROM ' +  @c_SourceDB + '.dbo.SERIALNO SN WITH (NOLOCK)  '  + CHAR(13) +  
                                    + ' JOIN Packserialno PAS WITH (NOLOCK) ON PAS.Serialno = SN.Serialno'
                                    + ' WHERE PAS.Pickslipno =  @c_Pickslipno ' 
  
                     SET @c_ExecArguments = N'@c_Pickslipno NVARCHAR(20),@c_SNTBLExists NVARCHAR(1) OUTPUT'  
                     EXEC sp_executesql @c_chkCSQL  
                                       , @c_ExecArguments  
                                       , @c_Pickslipno  
                                       , @c_SNTBLExists  OUTPUT  
      
                        IF @c_SNTBLExists = '1' AND @c_SNPDExists = '0' AND @c_SNPORDExists = '0'
                        BEGIN      
      
                           SET @c_ExecSQL=N' DECLARE CUR_MBSNKEY CURSOR FAST_FORWARD READ_ONLY FOR'        
                                      + ' SELECT DISTINCT SN.SerialNoKey,SN.storerkey, SN.serialno'        
                                      + ' FROM ' + @c_SourceDB + '.dbo.SERIALNO SN WITH (NOLOCK)'    
                                      + ' JOIN Packserialno PAS WITH (NOLOCK) ON PAS.Serialno = SN.Serialno'
                                      + ' WHERE PAS.Pickslipno =  @c_Pickslipno '    
                                      --+ ' UNION' + CHAR(13) +         
                                      --+ ' SELECT DISTINCT SN.SerialNoKey'        
                                      --+ ' FROM ' + @c_SourceDB + '.dbo.SERIALNO SN WITH (NOLOCK)'    
                                      --+ ' JOIN Pickdetail PID WITH (NOLOCK) ON PID.Orderkey = SN.orderkey'
                                      --+ ' WHERE PID.Pickslipno =  @c_Pickslipno '   
                                      --+ ' UNION' + CHAR(13) +         
                                      --+ ' SELECT DISTINCT SN.SerialNoKey'        
                                      --+ ' FROM ' + @c_SourceDB + '.dbo.SERIALNO SN WITH (NOLOCK)'    
                                      --+ ' JOIN Pickdetail PID WITH (NOLOCK) ON PID.Pickslipno = SN.Pickslipno'
                                      --+ ' WHERE  PID.Pickslipno =  @c_Pickslipno '            
                                      --+ ' ORDER BY SN.SerialNoKey '       
                         END 
                        
                         SET @c_chkCSQL = ''  
                         SET @c_chkCSQL = N'SELECT @c_SNPDExists = ''1'' ' + CHAR(13) +  
                                         ' FROM ' +  @c_SourceDB + '.dbo.SERIALNO SN WITH (NOLOCK)  '  + CHAR(13) +  
                                       + ' JOIN Pickdetail PID WITH (NOLOCK) ON PID.Orderkey = SN.orderkey'
                                       + ' WHERE PID.orderkey = @c_orderkey ' 
                                       + ' ORDER BY SN.SerialNoKey '       
  
                              SET @c_ExecArguments = N'@c_Pickslipno NVARCHAR(20), @c_orderkey NVARCHAR(20),@c_SNPDExists NVARCHAR(1) OUTPUT'  
                              EXEC sp_executesql @c_chkCSQL  
                                                , @c_ExecArguments  
                                                , @c_Pickslipno  
                                                , @c_orderkey  
                                                , @c_SNPDExists  OUTPUT  

                         IF  @c_SNTBLExists = '0' AND @c_SNPDExists = '1' AND @c_SNPORDExists = '0'
                         BEGIN                      

                                 SET @c_ExecSQL=N' DECLARE CUR_MBSNKEY CURSOR FAST_FORWARD READ_ONLY FOR'        
                                      + ' SELECT DISTINCT SN.SerialNoKey,SN.storerkey, SN.serialno'        
                                      + ' FROM ' + @c_SourceDB + '.dbo.SERIALNO SN WITH (NOLOCK)'      
                                      + ' JOIN Pickdetail PID WITH (NOLOCK) ON PID.Orderkey = SN.orderkey'
                                      + ' WHERE PID.orderkey = @c_orderkey'  
                                      + ' ORDER BY SN.SerialNoKey '   

                             -- SELECT '@c_SNPDExists Execsql' , @c_ExecSQL '@c_ExecSQL'

                         END 

                          SET @c_chkCSQL = ''  
                          SET @c_chkCSQL = N'SELECT @c_SNPORDExists = ''1'' ' + CHAR(13) +  
                                         ' FROM ' +  @c_SourceDB + '.dbo.SERIALNO SN WITH (NOLOCK)  '  + CHAR(13) +  
                                       + ' JOIN Pickdetail PID WITH (NOLOCK) ON PID.Pickslipno = SN.Pickslipno '
                                       + ' WHERE PID.Pickslipno =  @c_Pickslipno ' 
                                       + ' ORDER BY SN.SerialNoKey '       
  
                              SET @c_ExecArguments = N'@c_Pickslipno NVARCHAR(20),@c_SNPORDExists NVARCHAR(1) OUTPUT'  
                              EXEC sp_executesql @c_chkCSQL  
                                                , @c_ExecArguments  
                                                , @c_Pickslipno  
                                                , @c_SNPORDExists  OUTPUT  

                         IF  @c_SNTBLExists = '0' AND @c_SNPDExists = '0' AND @c_SNPORDExists = '1'
                         BEGIN

                             --SET @c_chkCSQL = ''  
                             -- SET @c_chkCSQL = N'SELECT @c_SNPDExists = ''1'' ' + CHAR(13) +  
                             --                ' FROM ' +  @c_SourceDB + '.dbo.SERIALNO SN WITH (NOLOCK)  '  + CHAR(13) +  
                             --                + ' JOIN Pickdetail PID WITH (NOLOCK) ON PID.Pickslipno = SN.Pickslipno '
                             --                + ' WHERE PID.Pickslipno =  @c_Pickslipno ' 
                             --                + ' ORDER BY SN.SerialNoKey '       
  
                             -- SET @c_ExecArguments = N'@c_Pickslipno NVARCHAR(20),@c_SNPDExists NVARCHAR(1) OUTPUT'  
                             -- EXEC sp_executesql @c_chkCSQL  
                             --                   , @c_ExecArguments  
                             --                   , @c_Pickslipno  
                             --                   , @c_SNPDExists  OUTPUT  

                                 SET @c_ExecSQL=N' DECLARE CUR_MBSNKEY CURSOR FAST_FORWARD READ_ONLY FOR'        
                                      + ' SELECT DISTINCT SN.SerialNoKey,SN.storerkey, SN.serialno'        
                                      + ' FROM ' + @c_SourceDB + '.dbo.SERIALNO SN WITH (NOLOCK)'      
                                      + ' JOIN Pickdetail PID WITH (NOLOCK) ON PID.Pickslipno = SN.Pickslipno'
                                      + ' WHERE PID.Pickslipno =  @c_Pickslipno '  
                                      + ' ORDER BY SN.SerialNoKey '   

                         END   
      
                     --SET @c_ExecSQL=N' DECLARE CUR_MBSNKEY CURSOR FAST_FORWARD READ_ONLY FOR'        
                     --                 + ' SELECT DISTINCT SN.SerialNoKey'        
                     --                 + ' FROM ' + @c_SourceDB + '.dbo.SERIALNO SN WITH (NOLOCK)'    
                     --                 + ' JOIN Packserialno PAS WITH (NOLOCK) ON PAS.Serialno = SN.Serialno'
                     --                 + ' WHERE PAS.Pickslipno =  @c_Pickslipno '    
                     --                 + ' UNION' + CHAR(13) +         
                     --                 + ' SELECT DISTINCT SN.SerialNoKey'        
                     --                 + ' FROM ' + @c_SourceDB + '.dbo.SERIALNO SN WITH (NOLOCK)'    
                     --                 + ' JOIN Pickdetail PID WITH (NOLOCK) ON PID.Orderkey = SN.orderkey'
                     --                 + ' WHERE PID.Pickslipno =  @c_Pickslipno '   
                     --                 + ' UNION' + CHAR(13) +         
                     --                 + ' SELECT DISTINCT SN.SerialNoKey'        
                     --                 + ' FROM ' + @c_SourceDB + '.dbo.SERIALNO SN WITH (NOLOCK)'    
                     --                 + ' JOIN Pickdetail PID WITH (NOLOCK) ON PID.Pickslipno = SN.Pickslipno'
                     --                 + ' WHERE  PID.Pickslipno =  @c_Pickslipno '            
                     --                 + ' ORDER BY SN.SerialNoKey '   

          --SELECT 'move serialno', @c_SNPDExists '@c_SNPDExists' ,@c_SNPORDExists  '@c_SNPORDExists',@c_ExecSQL '@c_ExecSQL'
           IF @c_ExecSQL <>''
           BEGIN
                        EXEC sp_executesql @c_ExecSQL,        
                                 N'@c_Pickslipno NVARCHAR(20), @c_orderkey NVARCHAR(20)',         
                                   @c_Pickslipno,@c_orderkey       
         
                        OPEN CUR_MBSNKEY        
           
                        FETCH NEXT FROM CUR_MBSNKEY INTO @c_SerialNoKey ,@c_Getstorerkey,@c_GetSN      
           
                        WHILE @@FETCH_STATUS <> -1        
                        BEGIN        
                        
                        SET @n_Continue = 1        
                        IF ISNULL(@c_SerialNoKey,'') <> ''      
                        BEGIN   
                             --EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'SERIALNO', 'SerialNoKey', @c_SerialNoKey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug               
                               EXEC isp_ReTriggerTransmitLog_MoveDataBYLine @c_SourceDB, @c_TargetDB, 'dbo', 'SERIALNO', 'SerialNoKey', @c_SerialNoKey,'storerkey',@c_Getstorerkey ,      
                                              'serialno',@c_GetSN,'', '',@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug  
                        END      
      
                        IF @b_Success <> 1 AND @c_errmsg <> ''      
                        BEGIN      
                          SET @n_continue=3      
                          GOTO QUIT      
                        END      
      
                        FETCH NEXT FROM CUR_MBSNKEY INTO @c_SerialNoKey ,@c_Getstorerkey,@c_GetSN          
                        END        
        
                        CLOSE CUR_MBSNKEY        
                        DEALLOCATE CUR_MBSNKEY   
       END   
      
   FETCH NEXT FROM CUR_SNBYMB INTO @c_orderkey          
   END          
          
   CLOSE CUR_SNBYMB          
   DEALLOCATE CUR_SNBYMB      
END 

END      
      
QUIT:      
      
IF @n_continue=3  -- Error Occured - Process And Return      
   BEGIN      
      SET @b_success = 0      
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt      
      BEGIN      
         ROLLBACK TRAN      
      END            ELSE      
      BEGIN      
         WHILE @@TRANCOUNT > @n_StartTCnt      
         BEGIN      
            COMMIT TRAN      
         END      
      END      
      --execute nsp_logerror @n_err, @c_errmsg, 'isp_RetriggerInterfaceSO'      
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


GO