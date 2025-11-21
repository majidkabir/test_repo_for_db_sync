SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_RCM_TRF_MICH_trflog_upd                        */
/* Creation Date: 08-MAR-2022                                           */
/* Copyright: LFL                                                       */
/* Written by:CHONGCS                                                   */
/*                                                                      */
/* Purpose: WMS-19041-TH-Michelin- Transfer new RCM to update T3 TRFLog */
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
/* 09-MAR-2022  CSCHONG   Devops Scripts Combine                        */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_RCM_TRF_MICH_trflog_upd]
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
           @c_GTRate                NVARCHAR(18),
           @c_MTRate                NVARCHAR(18),
           @n_GTRate                INT,
           @n_MTRate                INT,
           @n_QtyAvailable          INT,
           @n_GTQty                 INT,
           @n_MTQty                 INT,
           @n_Qty                   INT,
           @c_Lottable03            NVARCHAR(18),
           @c_ToLottable03          NVARCHAR(18),
           @n_QtyNeed               INT,
           @c_Lot                   NVARCHAR(10),
           @c_Loc                   NVARCHAR(10),
           @c_Id                    NVARCHAR(18),
           @n_QtyTake               INT,
           @c_NewTransferLineNumber NVARCHAR(5),
           @c_THType                NVARCHAR(12) = '',
           @c_CustomerRefNo         NVARCHAR(20) = '',
           @c_TFStatus              NVARCHAR(10) = '' 

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0

   SELECT TOP 1 @c_Facility = Facility,
                @c_Storerkey = FromStorerkey,
                @c_THType = [Type],
                @c_CustomerRefNo = CustomerRefNo
   FROM TRANSFER (NOLOCK)
   WHERE Transferkey = @c_Transferkey
   

IF @c_THType <> 'ORGPICKREQ' 
BEGIN 

         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Wrong Original Pick Request. (isp_RCM_TRF_MICH_trflog_upd)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO ENDPROC

END

   IF @n_continue IN (1,2)
   BEGIN 

        IF EXISTS ( SELECT 1 FROM TransmitLog3 (NOLOCK) WHERE TableName = 'TRFLOG'  
                      AND Key3 = @c_Storerkey AND Transmitflag ='H' AND  key1 IN(SELECT Transferkey FROM TRANSFER WITH (NOLOCK) WHERE type='PICK_REQUEST' AND status='9' AND CustomerRefNo=@c_CustomerRefNo)  )
        BEGIN

         BEGIN TRAN

                     UPDATE TransmitLog3 with (RowLOck)     
                     SET transmitflag = '0', TrafficCop = NULL           
                     WHERE TableName = 'TRFLOG'  
                    -- AND key1 = @c_Transferkey           
                     AND Key3 = @c_Storerkey 
                     AND Transmitflag ='H' 
                     AND  key1 IN (SELECT Transferkey FROM TRANSFER WITH (NOLOCK) WHERE type='PICK_REQUEST' AND status='9' AND CustomerRefNo=@c_CustomerRefNo) 
        
                       SELECT @n_err = @@ERROR            
                       IF @n_err <> 0             
                       BEGIN            
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                              SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TransmitLog3 fail. (isp_RCM_TRF_MICH_trflog_upd)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
                           
                           IF @@TRANCOUNT >= 1            
                           BEGIN            
                               ROLLBACK TRAN     
                                GOTO ENDPROC       
                           END            
                       END            
                       ELSE 
                       BEGIN            
                           IF @@TRANCOUNT > 0             
                           BEGIN            
                               COMMIT TRAN  
                               GOTO ENDPROC          
                           END            
                           ELSE 
                           BEGIN            
                               SELECT @n_continue = 3            
                               ROLLBACK TRAN   
                               GOTO ENDPROC
                           END            
                       END   
         END
         ELSE
         BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No Pick Request. (isp_RCM_TRF_MICH_trflog_upd)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
                     GOTO ENDPROC
         END
      
   END

ENDPROC:


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
     execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_TRF_MICH_trflog_upd'
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