SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/    
/* Stored Proc : ispPurgeStorer                                         */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by: Shong                                                    */    
/*                                                                      */    
/* Purpose: Purging Storer & all the transaction and historical data    */    
/*                                                                      */    
/* Called By:  Back End                                                 */    
/*                                                                      */    
/* PVCS Version: 1.2                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver  Purposes                                 */    
/* 07-Jan-2009  Shong     1.1  Include RCMReport                        */    
/* 11-Feb-2009  TLTING    1.2  Include StorerBilling for Consignee,     */    
/*                             CASEManifest    (tlting01)               */    
/* 04-Jan-2011  SHONG     1.3  Purge Consignee for type <> '1'          */  
/* 18-Jan-2012  KHLim01   1.4  Update ArchiveCop before purging         */  
/* 16-Feb-2012  KHLim02   1.5  prevent updating wrong InventoryHold     */  
/* 10-Jul-2019  TLTING    1.6  TLog ful tune                            */  
/* 01-Jul-2022  TLTING    1.7  New Table - OrderDetailRef,OrderInfo     */
/*            ,PackHeader,PickHeader,PickingInfo,Packdetail,PackSerialNo*/
/*            ,PackDetailInfo,PackdetailLabel,PackQRF,packinfo          */
/*            ,DocStatusTrack,LoadPLanLaneDetail,LoadPlanRetDetail      */
/*            ,LoadPlan_SUP_Detail, CartonShipmentDetail                */ 
/************************************************************************/    
CREATE   PROCEDURE [dbo].[ispPurgeStorer]    
    @c_Storer NVARCHAR(15)    
 AS    
 BEGIN     
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
    DECLARE @n_continue    int,    
            @n_starttcnt   int,       -- Holds the current transaction count    
            @n_cnt         int,       -- Holds @@ROWCOUNT after certain operations    
            @c_preprocess  NVARCHAR(250), -- preprocess    
            @c_pstprocess  NVARCHAR(250), -- post process    
            @n_err2        int,       -- For Additional Error Detection    
            @b_debug       int,       -- Debug 0 - OFF, 1 - Show ALL, 2 - Map    
            @b_success     int,    
            @n_err         int,         
            @c_errmsg      NVARCHAR(250),    
            @errorcount    int    
    
 SELECT @n_starttcnt=@@TRANCOUNT,     
        @n_continue=1,     
        @b_success=0,    
        @n_err=0,    
        @n_cnt = 0,    
        @c_errmsg='',    
        @n_err2=0    
    
 SELECT @b_debug = 0    
 Print 'Purge Storer '+RTrim(@c_storer)+' starts at ' + convert(char(20), getdate(), 120)    
 IF @n_Continue = 1    
 BEGIN    
    Print 'Updating Itrn ArchiveCop = 9'  -- KHLim01  
    UPDATE ITRN  
      SET ArchiveCop = '9'    
    WHERE  STORERKEY = @c_Storer  
            
    Print 'Purging Itrn..'    
    DELETE FROM ITRN     
    WHERE STORERKEY = @c_Storer    
    SELECT @n_err = @@ERROR    
    IF @n_err <> 0    
    BEGIN    
       SELECT @n_continue = 3    
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
    END    
 END    
    
 IF @n_Continue = 1    
 BEGIN    
    Print 'Updating Inventory Hold ArchiveCop = 9'    
    UPDATE InventoryHold     
      SET ArchiveCop = '9'    
    FROM   InventoryHold      
    JOIN LOT ON LOT.LOT = InventoryHold.LOT    
    WHERE  LOT.STORERKEY = @c_Storer    
            
    Print 'Purging Inventory Hold (Lot)'    
    DELETE InventoryHold    
    FROM   LOT    
    WHERE  LOT.STORERKEY = @c_Storer    
    AND    LOT.LOT = InventoryHold.LOT    
    SELECT @n_err = @@ERROR    
    IF @n_err <> 0    
    BEGIN    
       SELECT @n_continue = 3    
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
    END    
 END    
    
 IF @n_Continue = 1    
 BEGIN    
    Print 'Updating Inventory Hold ArchiveCop = 9'    
    UPDATE InventoryHold     
      SET ArchiveCop = '9'    
    FROM   InventoryHold      
    JOIN   LOTxLOCxID ON LOTxLOCxID.ID = InventoryHold.ID    
    WHERE  LOTxLOCxID.STORERKEY = @c_Storer    
    AND    InventoryHold.ID <> ''  -- KHLim02  
  
    Print 'Purging Inventory Hold (ID)'    
    DELETE InventoryHold    
    FROM   LOTxLOCxID    
    WHERE  LOTxLOCxID.STORERKEY = @c_Storer    
    AND    LOTxLOCxID.ID = InventoryHold.ID    
    AND    InventoryHold.ID <> ''  -- KHLim02  
    SELECT @n_err = @@ERROR    
    IF @n_err <> 0    
    BEGIN    
       SELECT @n_continue = 3    
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
    END    
 END    
 IF @n_Continue = 1    
 BEGIN    
    Print 'Updating Inventory Hold ArchiveCop = 9'    
    UPDATE InventoryHold     
      SET ArchiveCop = '9'    
    WHERE  InventoryHold.STORERKEY = @c_Storer    
    
    Print 'Purging Inventory Hold (ID)'    
    DELETE InventoryHold    
    WHERE  InventoryHold.STORERKEY = @c_Storer    
    SELECT @n_err = @@ERROR    
    IF @n_err <> 0    
    BEGIN    
       SELECT @n_continue = 3    
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
    END    
 END    
    
 IF @n_Continue = 1    
 BEGIN    
    Print 'Updating SKUxLOC ArchiveCop = 9'  -- KHLim01  
    UPDATE SKUxLOC     
      SET ArchiveCop = '9'    
    WHERE STORERKEY = @c_Storer    
  
    Print 'Purging SKUxLOC'    
    
    ALTER TABLE SKUxLOC disable trigger ntrSKUxLOCDelete     
    
    DELETE FROM SKUxLOC    
    WHERE STORERKEY = @c_Storer    
    SELECT @n_err = @@ERROR    
    IF @n_err <> 0    
    BEGIN    
       SELECT @n_continue = 3    
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
    END    
    
    ALTER TABLE SKUxLOC enable trigger ntrSKUxLOCDelete   -- KHLim01  
    
 END    
 IF @n_Continue = 1    
 BEGIN    
    Print 'Updating taskdetail...'    
    UPDATE TASKDETAIL    
     SET ArchiveCop = '9'    
    WHERE STORERKEY = @c_Storer    
    SELECT @n_err = @@ERROR    
    IF @n_err <> 0    
    BEGIN    
       SELECT @n_continue = 3    
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging Taskdetail...'    
       DELETE TASKDETAIL    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
 END    
 IF @n_Continue = 1    
 BEGIN    
    Print 'Updating PreAllocatePickdetail...'    
    UPDATE PreAllocatePickDETAIL    
     SET ArchiveCop = '9'    
  WHERE STORERKEY = @c_Storer    
    SELECT @n_err = @@ERROR    
    IF @n_err <> 0    
    BEGIN    
       SELECT @n_continue = 3    
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging PreAllocatePickdetail...'    
       DELETE PreAllocatePickDETAIL    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
 END    
 IF @n_Continue = 1    
 BEGIN    
    Print 'Updating Pickdetail...'    
    UPDATE PICKDETAIL    
     SET ArchiveCop = '9'    
    WHERE STORERKEY = @c_Storer    
    SELECT @n_err = @@ERROR    
    IF @n_err <> 0    
    BEGIN    
       SELECT @n_continue = 3    
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging Pickdetail...'    
       DELETE PICKDETAIL    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
 END    
 IF @n_Continue = 1    
 BEGIN    
    Print 'Updating POD...'    
    DELETE POD    
    FROM   ORDERS    
    WHERE  Orders.OrderKEY = POD.Orderkey    
    AND    ORDERS.StorerKey = @c_Storer    
    SELECT @n_err = @@ERROR    
    IF @n_err <> 0    
    BEGIN    
       SELECT @n_continue = 3    
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
    END    
 END    
  
 IF @n_Continue = 1    
 BEGIN   
    Print 'Updating PackHeader...'    
    UPDATE PackHeader    
     SET ArchiveCop = '9'    
    FROM   PackHeader    
    WHERE  PackHeader.StorerKey = @c_Storer    
    SELECT @n_err = @@ERROR    
    IF @n_err <> 0    
    BEGIN    
       SELECT @n_continue = 3    
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
    END    
    Print 'Updating PICKHEADER...'    
    UPDATE PICKHEADER    
     SET ArchiveCop = '9'    
    FROM   PICKHEADER    
    WHERE  PICKHEADER.StorerKey = @c_Storer    
    SELECT @n_err = @@ERROR    
    IF @n_err <> 0    
    BEGIN    
       SELECT @n_continue = 3    
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
    END  
    

    SELECT PACKHEADER.PickSlipNo  
    INTO #pickslip
    FROM  PACKHEADER (NOLOCK) WHERE  PACKHEADER.StorerKey = @c_Storer AND PACKHEADER.ArchiveCop = '9'  
    UNION ALL
    SELECT PICKHEADER.PickHeaderKey 
    FROM  PICKHEADER (NOLOCK) WHERE  PICKHEADER.StorerKey = @c_Storer AND PICKHEADER.ArchiveCop = '9'  

    Print 'Updating PickingInfo...'   
    UPDATE PickingInfo    
     SET ArchiveCop = '9'    
    FROM   PickingInfo    
    WHERE  EXISTS ( SELECT 2 FROM  #pickslip (NOLOCK) WHERE   #pickslip.PickSlipNo = PickingInfo.PickSlipNo )
    SELECT @n_err = @@ERROR    
    IF @n_err <> 0    
    BEGIN    
       SELECT @n_continue = 3    
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
    END  

    Print 'Updating packdetail...'  
    UPDATE packdetail    
     SET ArchiveCop = '9'    
    FROM   packdetail    
    WHERE  EXISTS ( SELECT 2 FROM  #pickslip (NOLOCK) WHERE   #pickslip.PickSlipNo = packdetail.PickSlipNo )
    SELECT @n_err = @@ERROR    
    IF @n_err <> 0    
    BEGIN    
       SELECT @n_continue = 3    
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
    END 

    Print 'Updating PackSerialNo...'  
    UPDATE PackSerialNo    
     SET ArchiveCop = '9'    
    FROM   PackSerialNo    
    WHERE  EXISTS ( SELECT 2 FROM  #pickslip (NOLOCK) WHERE   #pickslip.PickSlipNo = PackSerialNo.PickSlipNo )
    SELECT @n_err = @@ERROR    
    IF @n_err <> 0    
    BEGIN    
       SELECT @n_continue = 3    
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
    END  
    Print 'Updating PackDetailInfo...'  
    UPDATE PackDetailInfo    
     SET ArchiveCop = '9'    
    FROM   PackDetailInfo    
    WHERE  EXISTS ( SELECT 2 FROM  #pickslip (NOLOCK) WHERE   #pickslip.PickSlipNo = PackDetailInfo.PickSlipNo )
    SELECT @n_err = @@ERROR    
    IF @n_err <> 0    
    BEGIN    
       SELECT @n_continue = 3    
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
    END  
    Print 'Updating PackQRF...'  
    UPDATE PackQRF    
     SET ArchiveCop = '9'    
    FROM   PackQRF    
    WHERE  EXISTS ( SELECT 2 FROM  #pickslip (NOLOCK) WHERE   #pickslip.PickSlipNo = PackQRF.PickSlipNo )
    SELECT @n_err = @@ERROR    
    IF @n_err <> 0    
    BEGIN    
       SELECT @n_continue = 3    
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
    END      
    Print 'Updating PackdetailLabel...'  
    UPDATE PackdetailLabel    
     SET ArchiveCop = '9'    
    FROM   PackdetailLabel    
    WHERE  EXISTS ( SELECT 2 FROM  #pickslip (NOLOCK) WHERE   #pickslip.PickSlipNo = PackdetailLabel.PickSlipNo )
    SELECT @n_err = @@ERROR    
    IF @n_err <> 0    
    BEGIN    
       SELECT @n_continue = 3    
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
    END   
    Print 'Updating packinfo...'  
    UPDATE packinfo    
     SET ArchiveCop = '9'    
    FROM   packinfo    
    WHERE  EXISTS ( SELECT 2 FROM  #pickslip (NOLOCK) WHERE   #pickslip.PickSlipNo = packinfo.PickSlipNo )
    SELECT @n_err = @@ERROR    
    IF @n_err <> 0    
    BEGIN    
       SELECT @n_continue = 3    
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
    END  

    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging PackHeader...'    
       DELETE PackHeader    
       WHERE ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging PickHeader...'    
       DELETE PickHeader    
       WHERE ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging PickingInfo...'    
       DELETE PickingInfo    
       WHERE ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END   
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging Packdetail...'    
       DELETE Packdetail    
       WHERE ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END      
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging PackSerialNo...'    
       DELETE PackSerialNo    
       WHERE ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END     
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging PackDetailInfo...'    
       DELETE PackDetailInfo    
       WHERE ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END     
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging PackdetailLabel...'    
       DELETE PackdetailLabel    
       WHERE ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END  
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging PackQRF...'    
       DELETE PackQRF    
       WHERE ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END   
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging Packinfo...'    
       DELETE Packinfo    
       WHERE ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END       
 END

 IF @n_Continue = 1    
 BEGIN    
    Print 'Updating MBOL Detail...'    
    UPDATE MBOLDETAIL    
     SET ArchiveCop = '9'    
    FROM   ORDERS    
    WHERE  MBOLDETAIL.OrderKEY = ORDERS.OrderKey    
    AND    ORDERS.StorerKey = @c_Storer    
    SELECT @n_err = @@ERROR    
    IF @n_err <> 0    
    BEGIN    
       SELECT @n_continue = 3    
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating MBOL Header...'    
       UPDATE MBOL    
       SET ArchiveCop = '9'    
       FROM MBOLDETAIL    
       WHERE MBOL.MBOLKey = MBOLDETAIL.MBOLKey    
       AND   MBOLDETAIL.ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging MBOL Header...'    
       DELETE MBOL    
       WHERE ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
   END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging MBOL Detail...'    
       DELETE MBOLDETAIL    
       WHERE ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
 END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating Loadplan Detail...'    
       UPDATE LOADPLANDETAIL    
       SET ArchiveCop = '9'    
       FROM   ORDERS    
       WHERE  LOADPLANDETAIL.OrderKEY = ORDERS.OrderKey    
       AND    ORDERS.StorerKey = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    

    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating LoadPLanLaneDetail...'    
       UPDATE LoadPLanLaneDetail    
       SET ArchiveCop = '9'    
       FROM   LoadPLan     
       WHERE  LoadPLanLaneDetail.Loadkey = LoadPLan.Loadkey    
       AND    LoadPLan.ArchiveCop = '9'     
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating LoadPlanRetDetail...'    
       UPDATE LoadPlanRetDetail    
       SET ArchiveCop = '9'    
       FROM   LoadPLan     
       WHERE  LoadPlanRetDetail.Loadkey = LoadPLan.Loadkey    
       AND    LoadPLan.ArchiveCop = '9'     
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END   
    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating LoadPlanRetDetail...'    
       UPDATE LoadPlanRetDetail    
       SET ArchiveCop = '9'    
       FROM   LoadPLan     
       WHERE  LoadPlanRetDetail.Loadkey = LoadPLan.Loadkey    
       AND    LoadPLan.ArchiveCop = '9'     
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END   
    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating LoadPlan_SUP_Detail...'    
       UPDATE LoadPlan_SUP_Detail    
       SET ArchiveCop = '9'    
       FROM   LoadPLan     
       WHERE  LoadPlan_SUP_Detail.Loadkey = LoadPLan.Loadkey    
       AND    LoadPLan.ArchiveCop = '9'     
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END       
    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating Loadplan Header...'    
       UPDATE LoadPlan    
       SET ArchiveCop = '9'    
       FROM LOADPLANDETAIL    
       WHERE Loadplan.Loadkey = LoadPlanDetail.LoadKey    
       AND   Loadplandetail.archivecop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END   
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging LoadPLanLaneDetail...'    
       DELETE LoadPLanLaneDetail    
       WHERE  ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END 
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging LoadPlanRetDetail...'    
       DELETE LoadPlanRetDetail    
       WHERE  ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END     
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging LoadPlan_SUP_Detail...'    
       DELETE LoadPlan_SUP_Detail    
       WHERE  ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging Loadplan Driver...'    
       DELETE IDS_LP_DRIVER    
       FROM  LOADPLAN    
       WHERE LOADPLAN.LoadKey = IDS_LP_DRIVER.LoadKey    
       AND   ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging Loadplan Vehicle...'    
       DELETE IDS_LP_VEHICLE    
       FROM  LOADPLAN    
       WHERE LOADPLAN.LoadKey = IDS_LP_VEHICLE.LoadKey    
       AND   ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging Loadplan Detail...'    
       DELETE LoadplanDetail    
       WHERE ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging Loadplan Header...'    
       DELETE Loadplan    
       WHERE ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    

    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating DocStatusTrack...'    
       UPDATE DocStatusTrack    
       SET ArchiveCop = '9'    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging DocStatusTrack...'    
       DELETE DocStatusTrack    
       WHERE STORERKEY = @c_Storer    
       AND   ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END   

    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating CartonShipmentDetail...'    
       UPDATE CartonShipmentDetail    
       SET ArchiveCop = '9'    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging CartonShipmentDetail...'    
       DELETE CartonShipmentDetail    
       WHERE STORERKEY = @c_Storer    
       AND   ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END   

    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating OrderDetailRef...'    
       UPDATE OrderDetailRef    
       SET ArchiveCop = '9'    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging OrderDetailRef...'    
       DELETE OrderDetailRef    
       WHERE STORERKEY = @c_Storer    
       AND   ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    


    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating Order Detail...'    
       UPDATE ORDERDETAIL    
       SET ArchiveCop = '9'    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging Order Detail...'    
       DELETE ORDERDETAIL    
       WHERE STORERKEY = @c_Storer    
       AND   ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    

    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating Order Header...'    
       UPDATE ORDERS    
      SET ArchiveCop = '9'    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    

    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating Orders_PI_Encrypted ...'    
       UPDATE Orders_PI_Encrypted
       SET ArchiveCop = '9'
       FROM Orders_PI_Encrypted, ORDERS    (NOLOCK) 
       WHERE ORDERS.STORERKEY = @c_Storer    
       AND ORDERS.ArchiveCop = '9'
       AND Orders_PI_Encrypted.Orderkey =  ORDERS.Orderkey
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging Orders_PI_Encrypted...'    
       DELETE Orders_PI_Encrypted    
       FROM Orders_PI_Encrypted, ORDERS    (NOLOCK) 
       WHERE ORDERS.STORERKEY = @c_Storer    
       AND ORDERS.ArchiveCop = '9'
       AND Orders_PI_Encrypted.Orderkey =  ORDERS.Orderkey
       AND Orders_PI_Encrypted.ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    

    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating OrderInfo ...'    
       UPDATE OrderInfo
       SET ArchiveCop = '9'
       FROM OrderInfo, ORDERS    (NOLOCK) 
       WHERE ORDERS.STORERKEY = @c_Storer    
       AND ORDERS.ArchiveCop = '9'
       AND OrderInfo.Orderkey =  ORDERS.Orderkey
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging OrderInfo...'    
       DELETE OrderInfo    
       FROM OrderInfo, ORDERS    (NOLOCK) 
       WHERE ORDERS.STORERKEY = @c_Storer    
       AND ORDERS.ArchiveCop = '9'
       AND OrderInfo.Orderkey =  ORDERS.Orderkey
       AND OrderInfo.ArchiveCop = '9'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    

    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging Order Header...'    
       DELETE ORDERS    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1  -- KHLim01  
    BEGIN    
       Print 'Updating LOTxLOCxID...'    
       UPDATE LOTxLOCxID    
       SET ArchiveCop = '9'    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging LOTxLOCxID...'    
    
       ALTER TABLE LOTxLOCxID disable trigger ntrLOTxLOCxIDDelete    
    
       DELETE FROM LOTxLOCxID    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    
       ALTER TABLE LOTxLOCxID enable trigger ntrLOTxLOCxIDDelete    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging PHYSICAL...'    
       DELETE PHYSICAL    
       WHERE STORERKEY = @c_storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1  -- KHLim01  
    BEGIN    
       Print 'Updating ID...'    
       UPDATE ID    
       SET ArchiveCop = '9'    
       WHERE ID.ID NOT IN (SELECT DISTINCT ID FROM LOTxLOCxID )    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging ID...'    
       DELETE ID    
       WHERE ID.ID NOT IN (SELECT DISTINCT ID FROM LOTxLOCxID )    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1  -- KHLim01  
    BEGIN    
       Print 'Updating LOT...'    
       UPDATE LOT    
       SET ArchiveCop = '9'    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging LOT...'    
    
       ALTER TABLE LOT disable trigger ntrLOTdelete     
       DELETE FROM LOT    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    
       ALTER TABLE LOT enable trigger ntrLOTdelete     
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating Adjustment Detail...'    
       UPDATE ADJUSTMENTDETAIL    
        SET ARCHIVECOP = '9'    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating Adjustment Header...'    
       UPDATE ADJUSTMENT    
        SET ARCHIVECOP = '9'    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging Adjustment Detail...'    
       DELETE FROM ADJUSTMENTDETAIL    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging Adjustment Header...'    
       DELETE FROM ADJUSTMENT    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating Po Detail...'    
       UPDATE PODETAIL    
        SET ARCHIVECOP = '9'    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating PO ...'    
       UPDATE PO    
        SET ARCHIVECOP = '9'    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging PO Detail...'    
       DELETE FROM PODETAIL    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging PO Header...'    
       DELETE FROM PO    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating Transfer Detail...'    
       UPDATE TRANSFERDETAIL    
        SET ARCHIVECOP = '9'    
       WHERE FROMSTORERKEY = @c_Storer or TOSTORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating Transfer Header...'    
       UPDATE TRANSFER    
        SET ARCHIVECOP = '9'    
       WHERE FromStorerKey = @c_Storer or ToStorerkey = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging Transfer Detail...'    
       DELETE FROM TRANSFERDETAIL    
       WHERE FromStorerKey = @c_Storer or ToStorerkey = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging Transfer Header...'    
       DELETE FROM TRANSFER    
       WHERE FromStorerKey = @c_Storer or ToStorerkey = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
 -- begin    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating KIT Detail...'    
       UPDATE KitDetail    
        SET ARCHIVECOP = '9'    
       WHERE StorerKey = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating Kit Header...'    
       UPDATE KIT    
        SET ARCHIVECOP = '9'    
       WHERE StorerKey = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging KIT Detail...'    
       DELETE FROM KitDetail    
       WHERE StorerKey = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging KIT Header...'    
       DELETE FROM KIT    
       WHERE StorerKey = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END  
    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating InventoryQC Detail...'  
           
       UPDATE InventoryQCDetail    
          SET ARCHIVECOP = '9'   
       FROM InventoryQCDetail    
       JOIN InventoryQC iq ON iq.QC_Key = InventoryQCDetail.QC_Key               
       WHERE iq.StorerKey = @c_Storer     
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
          
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging InventoryQC Detail...'    
       DELETE FROM InventoryQCDetail  
       FROM InventoryQCDetail    
       JOIN InventoryQC iq ON iq.QC_Key = InventoryQCDetail.QC_Key               
       WHERE iq.StorerKey = @c_Storer              
    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
  
  
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging InventoryQC Header...'    
       DELETE FROM InventoryQC    
       WHERE StorerKey = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
 -- end    
    IF @n_Continue = 1    
    BEGIN    
     Print 'Updating Receipt Detail...'    
       UPDATE RECEIPTDETAIL    
       SET ArchiveCop = '9'    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Deleting Receipt Detail...'    
       DELETE RECEIPTDETAIL    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating Receipt Header...'    
       UPDATE RECEIPT    
       SET ArchiveCop = '9'    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
   BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging Receipt Header...'    
       DELETE RECEIPT    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    -- tlting01 - 2009/2/11  
    IF @n_Continue = 1    
    BEGIN    
       Print 'Updating CASEMANIFEST...'    
       UPDATE CASEMANIFEST    
       Set ArchiveCop = '9'    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END   
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging CASEMANIFEST...'    
       DELETE CASEMANIFEST    
       WHERE ArchiveCop = '9'   
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END   
    IF @n_Continue = 1  -- KHLim01  
    BEGIN    
       Print 'Updating LotAttribute...'    
       UPDATE LotAttribute    
       Set ArchiveCop = '9'    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END   
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging LotAttribute...'    
       WHILE 1=1  
       BEGIN  
          SET @n_cnt = 0  
          DELETE top (10000) FROM LOTATTRIBUTE    
          WHERE STORERKEY = @c_Storer    
          AND ArchiveCop = '9'   
          SELECT @n_err = @@ERROR  , @n_cnt = @@ROWCOUNT  
          IF @n_err <> 0    
          BEGIN    
             SELECT @n_continue = 3    
             SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
          END    
          IF @n_cnt = 0  
            Break  
       END  
    END    
    IF @n_Continue = 1  -- KHLim01  
    BEGIN    
       Print 'Updating Bill of Material...'    
       UPDATE BillOfMaterial    
       Set ArchiveCop = '9'    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END   
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging Bill of Material...'    
       DELETE FROM BillOfMaterial    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging UPC...'    
       DELETE FROM UPC    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    
    IF @n_Continue = 1  -- KHLim01  
    BEGIN    
       Print 'Updating SKU...'    
  
       WHILE 1 = 1  
       BEGIN  
          SET @n_cnt = 0  
          UPDATE TOP (100000) SKU    
          Set ArchiveCop = '9'    
          WHERE STORERKEY = @c_Storer    
          AND ( ArchiveCop <> '9' OR ArchiveCop is NULL)  
          SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT     
          IF @n_err <> 0    
          BEGIN    
             SELECT @n_continue = 3    
             SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
          END    
  
          IF @n_cnt = 0  
             BREAK  
       END  
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging SKU...'    
  
       WHILE 1 = 1  
       BEGIN  
          SET @n_cnt = 0  
          DELETE TOP (100000) FROM SKU    
          WHERE STORERKEY = @c_Storer    
          AND ArchiveCop = '9'  
          SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT     
          IF @n_err <> 0    
          BEGIN    
             SELECT @n_continue = 3    
             SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
          END    
  
          IF @n_cnt = 0  
             BREAK  
        END  
  
     END    
    
    IF @n_Continue = 1    
    BEGIN    
        -- tlting01 2009/2/11  
       Print 'Purging Consignee - STORERBILLING...'    
       DELETE FROM STORERBILLING  
       Where Storerkey in ( Select Storerkey from STORER    
                            WHERE ConsigneeFor = @c_Storer  )  
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
     END    
    
    IF @n_Continue = 1  -- KHLim01  
    BEGIN    
       Print 'Updating Consignee...'    
       UPDATE STORER    
       Set ArchiveCop = '9'    
       WHERE ConsigneeFor = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN              
       Print 'Purging Consignee...'    
       DELETE FROM STORER    
       WHERE ConsigneeFor = @c_Storer  
         AND TYPE <> '1'    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging RCMReport...'    
       DELETE FROM RCMReport    
       WHERE Storerkey = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    
    IF @n_Continue = 1  -- KHLim01  
    BEGIN    
       Print 'Updating Storer Billing...'    
       UPDATE STORERBILLING    
       Set ArchiveCop = '9'    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging Storer Billing...'    
       DELETE FROM STORERBILLING    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1  -- KHLim01  
    BEGIN    
       Print 'Updating Storer...'    
       UPDATE STORER    
       Set ArchiveCop = '9'    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
    END    
    IF @n_Continue = 1    
    BEGIN    
       Print 'Purging Storer...'    
       DELETE FROM STORER    
       WHERE STORERKEY = @c_Storer    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '    
       END    
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
   END    
   Print 'Purge Storer '+RTrim(@c_storer)+' ends at ' + convert(char(20), getdate(), 120)    
END -- procedure    

GO