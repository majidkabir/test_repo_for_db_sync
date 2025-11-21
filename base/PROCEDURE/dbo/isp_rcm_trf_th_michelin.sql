SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RCM_TRF_TH_Michelin                            */
/* Creation Date: 08-FEB-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-18843 TH-Michelin - Transfer enhance for Pick Request   */
/*                                                                      */
/* Called By: Transfer Dymaic RCM configure at listname 'RCMConfig'     */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/*08-FEB-2022   CSCHONG   1.0   Devops Scripts Combine                  */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_RCM_TRF_TH_Michelin]
   @c_Transferkey NVARCHAR(10),   
   @b_success  int OUTPUT,
   @n_err      int OUTPUT,
   @c_errmsg   NVARCHAR(225) OUTPUT,
   @c_code     NVARCHAR(30)=''
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue  INT,
           @n_cnt       INT,
           @n_starttcnt INT
           
   DECLARE @c_Facility              NVARCHAR(5),
           @c_storerkey             NVARCHAR(15),
           @c_Sku                   NVARCHAR(20),
           @c_UOM                   NVARCHAR(10),
           @c_Packkey               NVARCHAR(10),
           @c_TransferLineNumber    NVARCHAR(5), 
           @c_transferType          NVARCHAR(20), 
           @c_transferUDF10         NVARCHAR(20),
           @c_TransferCustomerRefNo NVARCHAR(20),
           @c_transferUDF01         NVARCHAR(20),
           @n_QtyNeed               INT,
           @c_transferUDF06         NVARCHAR(20), 
           @c_transferUDF07         NVARCHAR(20), 
           @c_transferUDF08         NVARCHAR(20), 
           @n_QtyTake               INT,
           @c_NewTransferLineNumber NVARCHAR(5),
           @c_GetOriTransferkey     NVARCHAR(10) = '',
           @c_TRFDETUDF02           NVARCHAR(20) = '',
           @c_TRFDETUDF03           NVARCHAR(20) = '',
           @c_TRFDETUDF04           NVARCHAR(20) = '',
           @c_TRFDETUDF05           NVARCHAR(20) = '' ,
          
          @c_GetOriTransferCustomerRefNo NVARCHAR(20) = ''
              
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0 
   
   SELECT TOP 1 @c_Facility = Facility,
                @c_Storerkey = FromStorerkey
   FROM TRANSFER (NOLOCK)
   WHERE Transferkey = @c_Transferkey
   
   IF @n_continue IN (1,2)
   BEGIN
        --Get transfer info
      SELECT @c_transferType = TRF.Type 
            ,@c_transferUDF10 = TRF.UserDefine10
            ,@c_TransferCustomerRefNo = TRF.CustomerRefNo
      FROM TRANSFER TRF(NOLOCK)
      WHERE Transferkey = @c_Transferkey

      
      IF @c_transferType <> 'PICK_REQUEST'
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Wrong Type to Import. (isp_RCM_TRF_TH_Michelin)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO ENDPROC         
      END
      
      IF ISNULL(@c_transferUDF10,'') = ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Wrong Source Transferkey (isp_RCM_TRF_TH_Michelin)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO ENDPROC         
      END            
      
      IF @n_continue IN (1,2)
      BEGIN
      SET @c_GetOriTransferkey = ''

      SET @c_transferUDF01 = ''
      SET @c_transferUDF06 = ''
      SET @c_transferUDF07 = ''
      SET @c_transferUDF08 = ''
     
      SELECT @c_GetOriTransferkey = TRF.transferkey
      FROM dbo.TRANSFER TRF WITH (NOLOCK)
      --WHERE TRF.UserDefine10 = @c_transferUDF10
      WHERE TRF.CustomerRefNo = @c_TransferCustomerRefNo
      AND TRF.Type = 'ORGPICKREQ'


       SELECT @c_transferUDF01 = TRF.UserDefine01
             ,@c_transferUDF06 = TRF.UserDefine06
             ,@c_transferUDF07 = TRF.UserDefine07
             ,@c_transferUDF08 = TRF.UserDefine08
             ,@c_GetOriTransferCustomerRefNo = TRF.CustomerRefNo  
       FROM dbo.TRANSFER TRF WITH (NOLOCK)
       WHERE TRF.TransferKey = @c_GetOriTransferkey


    

       UPDATE TRANSFER WITH (ROWLOCK)
        SET UserDefine01 = @c_transferUDF01
            ,UserDefine06 = @c_transferUDF06
            ,UserDefine07 = @c_transferUDF07
            ,UserDefine08 = @c_transferUDF08   
            WHERE Transferkey = @c_Transferkey
            
            SELECT @n_err = @@ERROR
             IF @n_err <> 0
             BEGIN
               SET @n_continue = 3
               SET @n_err = 82090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update Transfer Failed! (isp_RCM_TRF_TH_Michelin)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
               GOTO ENDPROC 
             END
                                
      
      --Process transferdetail and update userdefine
      DECLARE CUR_TRANSFERDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT DISTINCT TRD.TransferLineNumber, TRD.FromStorerKey,TRD.FromSku
         FROM dbo.TRANSFERDETAIL TRD
         WHERE TRD.TransferKey = @c_Transferkey
         ORDER BY TRD.TransferLineNumber            

      OPEN CUR_TRANSFERDET  
      FETCH NEXT FROM CUR_TRANSFERDET INTO @c_TransferLineNumber, @c_Storerkey,@c_sku

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN         


        
      SET @c_TRFDETUDF02 = ''
      SET @c_TRFDETUDF03 = ''
      SET @c_TRFDETUDF04 = ''
      SET @c_TRFDETUDF05 = ''

      SELECT TOP 1  @c_TRFDETUDF02 = TRFD.UserDefine02
                   ,@c_TRFDETUDF03 = TRFD.UserDefine03
                   ,@c_TRFDETUDF04 = TRFD.UserDefine04
                   ,@c_TRFDETUDF05 = TRFD.UserDefine05
      FROM dbo.TRANSFERDETAIL TRFD WITH (NOLOCK)
      WHERE TRFD.TransferKey=@c_GetOriTransferkey
      AND TRFD.FromSku = @c_sku                    
              
        UPDATE TRANSFERDETAIL WITH (ROWLOCK)  
        SET Userdefine02 = @c_TRFDETUDF02
           ,Userdefine03 = @c_TRFDETUDF03
           ,Userdefine04 = @c_TRFDETUDF04
           ,Userdefine05 = @c_TRFDETUDF05
           ,Userdefine10 = @c_GetOriTransferCustomerRefNo
      WHERE Transferkey = @c_Transferkey  
      AND TransferLineNumber = @c_TransferLineNumber  
      AND FROMSKU = @c_sku
            
             SELECT @n_err = @@ERROR
             IF @n_err <> 0
             BEGIN
               SET @n_continue = 3
               SET @n_err = 82100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update Transferdetail Failed! (isp_RCM_TRF_TH_Michelin)' + '( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(RTRIM(@c_errmsg)) + ' ) '
              END           
      
         FETCH NEXT FROM CUR_TRANSFERDET INTO @c_TransferLineNumber, @c_Storerkey,@c_sku
      END
      CLOSE CUR_TRANSFERDET
      DEALLOCATE CUR_TRANSFERDET  
    END                   
   END   
        
ENDPROC: 
 
   IF (SELECT CURSOR_STATUS('LOCAL','CUR_TRANSFERDET')) >=0 
   BEGIN
      CLOSE CUR_TRANSFERDET           
      DEALLOCATE CUR_TRANSFERDET      
   END  
 

   IF @n_continue=3  -- Error Occured - Process And Return
    BEGIN
       SELECT @b_success = 0
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
     execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_TRF_TH_Michelin'
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
       RETURN
    END
    ELSE
       BEGIN
          SELECT @b_success = 1
          WHILE @@TRANCOUNT > @n_starttcnt
          BEGIN
             COMMIT TRAN
          END
          RETURN
       END     
END -- End PROC

GO