SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/  
/* Stored Procedure: isp_PrintCartonLabel_Interface                        */  
/* Creation Date: 31-MAY-2016                                              */  
/* Copyright: LFL                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose: SOS#370148 - SG - Nike Ecom Packing. Print carton label by     */                                 
/*          interface/web service.                                         */
/*          storerconfig PrintCartonLabelByITF='1' option1=<tablename>     */
/*          If @c_errmsg='CONTINUE PRINT' and success will continue        */
/*          print UCC label                                                */
/*                                                                         */  
/* Called By: Packing Module - Print UCC Label                             */  
/*                                                                         */  
/*                                                                         */  
/* PVCS Version: 1.0                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date           Ver    Author   Purposes                                 */  
/* 08-JAN-2019 1.1   SWT01    For immediate trigger label extract web      */
/*                            service                                      */ 
/* 05-Jul-2019 1.1   NJOW01   WMS-9396 SG THG support custom sp            */
/*                            (ispCTNLBLITF??)                             */
/* 20-SEP-2019 1.2   CSCHONG  WMS-10640 (CS01)                             */
/* 31-OCT-2019 1.3   CSCHONG  Fix error for THGSG (CS02)                   */
/***************************************************************************/    
CREATE PROC [dbo].[isp_PrintCartonLabel_Interface]    
(     @c_Pickslipno   NVARCHAR(10)     
  ,   @n_CartonNo_Min INT 
  ,   @n_CartonNo_Max INT 
  ,   @b_Success     INT           OUTPUT  
  ,   @n_Err         INT           OUTPUT  
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT     
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @b_Debug                 INT  
         , @n_Continue              INT   
         , @n_StartTCount           INT   
         , @c_Storerkey             NVARCHAR(10)
         , @c_PrintCartonLabelByITF NVARCHAR(10)
         , @c_Option1               NVARCHAR(50)
         , @c_Option2               NVARCHAR(50)
         , @c_Option3               NVARCHAR(50)
         , @c_CartonNo              NVARCHAR(10)
         , @c_UserName              NVARCHAR(18)         
         , @c_Facility              NVARCHAR(5)
         , @c_PrintData             NVARCHAR(4000)
         , @c_Orderkey              NVARCHAR(10)
         , @c_RefNo                 NVARCHAR(20)
         , @c_LabelNo               NVARCHAR(20)
         , @c_trmlogkey             NVARCHAR(10)
         , @c_RDTDefaultPrinter     NVARCHAR(128)
         , @c_RDTWinPrinter         NVARCHAR(128)
         , @c_SPCode                NVARCHAR(50)
         , @c_SQL                   NVARCHAR(MAX)

   SET @b_Success= 1   
   SET @n_Err    = 0    
   SET @c_ErrMsg = ''  
 
   SET @b_Debug  = 0
   SET @n_Continue = 1    
   SET @n_StartTCount = @@TRANCOUNT  
   
   SELECT TOP 1 @c_Storerkey = Storerkey
   FROM PACKHEADER(NOLOCK)
   WHERE Pickslipno = @c_Pickslipno
   
   Execute nspGetRight 
      '',  
      @c_StorerKey,              
      '',                    
      'PrintCartonLabelByITF', 
      @b_success               OUTPUT,
      @c_PrintCartonLabelByITF OUTPUT,
      @n_err                   OUTPUT,
      @c_errmsg                OUTPUT,
      @c_Option1               OUTPUT,
      @c_Option2               OUTPUT,
      @c_Option3               OUTPUT      

   --NJOW01 Start
   SELECT @c_SPCode = @c_Option3   

   IF ISNULL(@c_SPCode,'') <> ''
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')  
      BEGIN  
            SET @n_Continue = 3
            SET @n_err      = 83000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+
            ': Storerconfig PrintCartonLabelByITF.Option3 - Stored Proc name invalid (isp_PrintCartonLabel_Interface)'        
         GOTO QUIT_SP  
      END        
            
      SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_Pickslipno=@c_PickslipnoP, @n_CartonNo_Min=@n_CartonNo_MinP, @n_CartonNo_Max=@n_CartonNo_MaxP, @b_Success=@b_SuccessP OUTPUT, @n_Err=@n_ErrP OUTPUT, @c_ErrMsg=@c_ErrMsgP OUTPUT '  
      
      EXEC sp_executesql @c_SQL   
          ,N'@c_PickslipnoP NVARCHAR(10), @n_CartonNo_MinP INT, @n_CartonNo_MaxP INT, @b_SuccessP INT OUTPUT, @n_ErrP INT OUTPUT, @c_ErrMsgP NVARCHAR(255) OUTPUT '   
          ,@c_Pickslipno       
          ,@n_CartonNo_Min
          ,@n_CartonNo_Max
          ,@b_Success      OUTPUT  
          ,@n_Err          OUTPUT  
          ,@c_ErrMsg       OUTPUT           

       IF @b_Success <> 1
       BEGIN
         SET @n_Continue = 3
       END                    

      --CS01 Start
      IF @n_Continue > 1 
      BEGIN
         GOTO QUIT_SP             
      END
      ELSE
      BEGIN  --CS02 START
         IF @c_ErrMsg = '' OR @c_ErrMsg <> 'CONTINUE'
         BEGIN
            GOTO QUIT_SP
         END
      END --CS02 END
      --CS01 END
   END      
   --NJOW01 End
      
   IF @c_PrintCartonLabelByITF = '1'
   BEGIN
      IF ISNULL(@c_Option1,'') = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_err      = 83000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+
            ': Please setup table name at option1 of storerconfig ''PrintCartonLabelByITF'' (isp_PrintCartonLabel_Interface)'
         GOTO QUIT_SP
      END
        
      DECLARE cur_Carton CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT RTRIM(LTRIM(CAST(PACKDETAIL.CartonNo AS NVARCHAR))), MAX(PACKDETAIL.AddWho), 
             ORDERS.Facility, ORDERS.Orderkey, MAX(PACKDETAIL.Refno), PACKDETAIL.LabelNo
      FROM PACKDETAIL(NOLOCK)
      JOIN PACKHEADER (NOLOCK) ON PACKDETAIL.Pickslipno = PACKHEADER.Pickslipno
      JOIN ORDERS (NOLOCK) ON PACKHEADER.Orderkey = ORDERS.Orderkey
      WHERE PACKHEADER.Pickslipno = @c_Pickslipno
      AND PACKDETAIL.CartonNo BETWEEN @n_CartonNo_Min AND @n_CartonNo_Max
      GROUP BY RTRIM(LTRIM(CAST(PACKDETAIL.CartonNo AS NVARCHAR))), ORDERS.Facility, ORDERS.Orderkey, PACKDETAIL.LabelNo
      ORDER BY 1
         
      OPEN cur_Carton  
      FETCH NEXT FROM cur_Carton INTO @c_CartonNo, @c_UserName, @c_Facility, @c_Orderkey, @c_Refno, @c_LabelNo     
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN     
            /*         
            SET @c_PrintData = ''
             
           IF NOT EXISTS ( SELECT 1 FROM TransmitLog2 (NOLOCK) WHERE TableName = @c_Option1 
                                AND Key1 = @c_Pickslipno AND Key2 = @c_CartonNo AND Key3 = @c_Storerkey 
                                AND transmitflag IN('0','1','9'))
            BEGIN             
               SELECT @b_success = 1
               EXECUTE nspg_getkey
               'TransmitlogKey2'
               , 10
               , @c_trmlogkey OUTPUT
               , @b_success   OUTPUT
               , @n_err       OUTPUT
               , @c_errmsg    OUTPUT
               
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
               END
               ELSE
               BEGIN
                  INSERT INTO Transmitlog2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)
                  VALUES (@c_trmlogkey, @c_Option1, @c_Pickslipno, @c_CartonNo, @c_Storerkey, '0', '')
               END
            END
            ELSE
            BEGIN
               --SELECT TOP 1 @c_PrintData = PrintData 
               --FROM CARTONTRACK (NOLOCK)
               --WHERE LabelNo = @c_LabelNo
               --AND TrackingNo = @c_RefNo
              
               --IF ISNULL(@c_PrintData,'') <> ''
               --BEGIN   
               -- EXEC isp_PrintToRDTSpooler 
          --    @c_reporttype = ''
          --   ,@c_Storerkey = @c_Storerkey
          --   ,@b_success = @b_success  OUTPUT
          --   ,@n_err = @n_err OUTPUT
          --   ,@c_errmsg = @c_errmsg OUTPUT
          --   ,@c_Param01 = @c_pickslipno
          --   ,@c_Param02 = @c_cartonno
          --   ,@c_UserName = @c_UserName
          --   ,@c_Facility = @c_Facility
          --   ,@c_JobType = 'DIRECTPRN'
          --   ,@c_PrintData = @c_PrintData
                      
               -- IF @b_Success <> 1
               --    SELECT @n_continue = 3
               --END 
               
               --Get Default Printer
               SET @c_RDTDefaultPrinter = ''
               SELECT @c_RDTDefaultPrinter = ISNULL(RTRIM(DefaultPrinter), '')
               FROM rdt.rdtUser WITH (NOLOCK)
               WHERE UserName = @c_UserName
               
               --Get WinPrinter
               SET @c_RDTWinPrinter = ''
               SELECT @c_RDTWinPrinter = ISNULL(RTRIM(WinPrinter), '')
               FROM rdt.rdtPrinter WITH (NOLOCK)
               WHERE PrinterID = @c_RDTDefaultPrinter
         
               SET @c_RDTDefaultPrinter = SUBSTRING(@c_RDTWinPrinter, 1, CHARINDEX(',winspool',@c_RDTWinPrinter) - 1) 
               
               --Excute Print Label SP
               EXEC dbo.isp_PrintZplLabel 
               @c_StorerKey
               , '' --@cLabelNo
               , @c_RefNo
               , @c_RDTDefaultPrinter
               , @n_Err OUTPUT
               , @c_ErrMsg OUTPUT                           
            END
            */

            SELECT @b_success = 1
           EXECUTE nspg_getkey
           'TransmitlogKey2'
           , 10
           , @c_trmlogkey OUTPUT
           , @b_success   OUTPUT
           , @n_err       OUTPUT
           , @c_errmsg    OUTPUT
           
           IF @b_success <> 1
           BEGIN
               SELECT @n_continue = 3
           END
           ELSE
           BEGIN
            INSERT INTO Transmitlog2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)
            VALUES (@c_trmlogkey, @c_Option1, @c_Pickslipno, @c_CartonNo, @c_Storerkey, '0', '')
              
                -- Added by SWT01 for immediate trigger label extract web service 
                IF EXISTS(SELECT 1 FROM QCmd_TransmitlogConfig AS qtc WITH(NOLOCK)
                          WHERE qtc.PhysicalTableName='TRANSMITLOG2' 
                          AND qtc.TableName = @c_Option1 
                          AND qtc.StorerKey = @c_Storerkey
                          AND qtc.QCmdClass = 'FRONTEND')
                BEGIN
                   SET @n_err = 0 
                   EXEC  [dbo].[isp_QCmd_WSTransmitLogInsertAlert] 
                          @c_QCmdClass            = 'FRONTEND'      
                        , @c_FrmTransmitlogKey    = @c_trmlogkey 
                        , @c_ToTransmitlogKey     = @c_trmlogkey                
                        , @b_Debug                = 0            
                        , @b_Success              = @b_success OUTPUT                
                        , @n_Err                  = @n_err     OUTPUT
                        , @c_ErrMsg               = @c_errmsg  OUTPUT
                   
                 IF @n_err <> 0
                 BEGIN
                    SET @n_Continue = 3
                    GOTO QUIT_SP
                 END                    
                END
           END
         
      FETCH NEXT FROM cur_Carton INTO @c_CartonNo, @c_UserName, @c_Facility, @c_Orderkey, @c_Refno, @c_LabelNo
      END
      CLOSE cur_Carton  
      DEALLOCATE cur_Carton                                                         
   END
                 
   QUIT_SP:  
  
   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_success = 0  
  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCount  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      Execute nsp_logerror @n_err, @c_errmsg, 'isp_PrintCartonLabel_Interface'  
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         COMMIT TRAN  
      END   
  
      RETURN  
   END   
END 

GO