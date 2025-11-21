SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_PrintStoreAddressedLabel_WTC                   */
/* Creation Date: 24-Jan-2006                           						*/
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                          			*/
/*                                                                      */
/* Purpose:  SOS45047 WTCPH Print Store-Addressed Label 				      */
/*           Notes: 1) If orders allocated, update CaseID ='(STORADDR)' */
/*                  2) Label format is 'S' + ReceiptKey + 3 digits      */
/*                  3) Label size is 2" x 1"                            */
/*                                                                      */
/* Input Parameters:  @c_storerkey, - storerkey                         */
/*                    @c_refkey,    - externreceiptkey                  */
/*							 @c_qty	      - number of labels to be printed    */
/*                                                                      */
/* Called By:  dw = r_dw_storaddlabel_wtc             		            */
/*                                                                      */
/* PVCS Version: 1.0		                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/*																								*/
/************************************************************************/

CREATE PROC [dbo].[nsp_PrintStoreAddressedLabel_WTC] (
   @c_storerkey NVARCHAR(15), 
   @c_refkey NVARCHAR(20), 
   @c_qty NVARCHAR(10)
) 
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_PickDetailKey NVARCHAR(10),
      @c_ReceiptKey         NVARCHAR(10),
      @n_TotalNoOfLabel     int,
      @c_StoreAddrLabel     NVARCHAR(20),
      @n_Cnt                int,
	   @n_continue		       int,
	   @c_errmsg		       NVARCHAR(255),
	   @b_success		       int,
	   @n_err			       int,
		@n_starttcnt          int

   CREATE TABLE #TEMPPICKDETAIL (
			PickDetailKey	 NVARCHAR(10)) 

	CREATE TABLE #TEMPLABEL (
			ReceiptKey		   NVARCHAR(10),
         StorerKey         NVARCHAR(15),
         ExternReceiptKey  NVARCHAR(20),
         SeqOfLabel        int,          
         StoreAddrLabel    NVARCHAR(20) )

   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT 
   SELECT @n_Cnt = 0

   BEGIN TRAN

   -- Validate Qty of Labels
   IF ISNUMERIC (@c_qty) = 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63101   
   	SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Number of Labels should be numeric. ' + 
                         ' (nsp_PrintStoreAddressedLabel_WTC)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      GOTO EXIT_SP
   END

   IF @c_qty <= 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63102   
   	SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Number of Labels should be greater than zero. ' + 
                         ' (nsp_PrintStoreAddressedLabel_WTC)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      GOTO EXIT_SP
   END
  
   -- Verification of CaseID
   -- Check whether orders already allocated before print store-addressed label. 
   -- If allocated, update CaseID to (STORADDR)
   INSERT INTO #TEMPPICKDETAIL
   SELECT DISTINCT PD.PickDetailKey
   FROM PickDetail PD (NOLOCK)
   INNER JOIN OrderDetail OD (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND
                                          PD.OrderLineNumber = OD.OrderLineNumber)
   INNER JOIN ReceiptDetail RD (NOLOCK) ON (RD.StorerKey = PD.StorerKey AND
                                           RD.ExternReceiptKey = OD.ExternPOKey)
   INNER JOIN Receipt RH (NOLOCK) ON (RH.ReceiptKey = RD.ReceiptKey)                                           
   WHERE RD.StorerKey = @c_storerkey
   AND   RD.ExternReceiptKey = @c_refkey
   AND   RD.FinalizeFlag = 'Y'      
   AND   RH.Status = '9'
   AND   PD.Status < '9'
   AND   PD.CaseID = ''
   
   WHILE @@TRANCOUNT > @n_starttcnt
      COMMIT TRAN

   IF (SELECT COUNT(1) FROM #TEMPPICKDETAIL) > 0 
   BEGIN 
      BEGIN TRAN
    
      DECLARE PD_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PickDetailKey
         FROM   #TEMPPICKDETAIL
         ORDER BY PickDetailKey

   	OPEN PD_CUR
   
   	FETCH NEXT FROM PD_CUR INTO @c_PickDetailKey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Update PickDetail with trafficcop = NULL (not invoke trigger)
         UPDATE PICKDETAIL WITH (ROWLOCK)
         SET   TrafficCop = NULL,
               CaseID = '(STORADDR)'
         WHERE PickDetailKey = @c_PickDetailKey
         AND   Status < '9'
         AND   CaseID = ''
         
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63103   
         	SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update PickDetail Failed. ' + 
                               ' (nsp_PrintStoreAddressedLabel_WTC)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            GOTO EXIT_SP
         END

         FETCH NEXT FROM PD_CUR INTO @c_PickDetailKey
      END

      CLOSE PD_CUR
      DEALLOCATE PD_CUR
   END

   WHILE @@TRANCOUNT > @n_starttcnt
      COMMIT TRAN

   -- Generate Store-Addressed Label
   -- Assume one ExternReceiptKey (ExternPOKey) only tie to one Receipt
   SELECT @c_ReceiptKey = ''
   SELECT @c_ReceiptKey = RH.ReceiptKey 
   FROM  Receipt RH (NOLOCK)
   INNER JOIN ReceiptDetail RD (NOLOCK) ON (RH.ReceiptKey = RD.ReceiptKey)
   WHERE RD.StorerKey = @c_storerkey
   AND   RD.ExternReceiptKey = @c_refkey
   AND   RH.Status = '9'
   AND   RD.FinalizeFlag = 'Y'      
   GROUP BY RH.ReceiptKey

   IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_ReceiptKey)) <> ''
   BEGIN     
      BEGIN TRAN

      SELECT @n_Cnt = 1, @c_StoreAddrLabel = ''

      SELECT @n_TotalNoOfLabel = CONVERT (INT, @c_qty)
             
      WHILE @n_Cnt <= @n_TotalNoOfLabel
      BEGIN
         -- Format is 'S' + ReceiptKey + 3 running number based on total number of labels generated
         SELECT @c_StoreAddrLabel = 'S'+ @c_ReceiptKey + RIGHT (REPLICATE('0',3) + dbo.fnc_RTrim(CONVERT (char(10), @n_Cnt)),3)
         
         INSERT INTO #TEMPLABEL 
            (ReceiptKey, StorerKey, ExternReceiptKey, SeqOfLabel, StoreAddrLabel)
         VALUES
            (@c_ReceiptKey, @c_storerkey, @c_refkey, @n_Cnt, @c_StoreAddrLabel)

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63104   
         	SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert #TEMPLABEL Failed. ' + 
                               ' (nsp_PrintStoreAddressedLabel_WTC)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            GOTO EXIT_SP
         END
         
         SELECT @n_Cnt = @n_Cnt + 1
      END

      WHILE @@TRANCOUNT > @n_starttcnt
         COMMIT TRAN

   END
   ELSE
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63105   
   	SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': ReceiptKey NOT Found. ' + 
                         ' (nsp_PrintStoreAddressedLabel_WTC)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      GOTO EXIT_SP
   END

   -- Retrieve values
   SELECT ReceiptKey, StorerKey, ExternReceiptKey, SeqOfLabel, StoreAddrLabel
   FROM #TEMPLABEL

   DROP TABLE #TEMPPICKDETAIL
   DROP TABLE #TEMPLABEL

   EXIT_SP: 
   IF @n_continue = 3
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      ROLLBACK TRAN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_PrintStoreAddressedLabel_WTC'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      /* Error Did Not Occur , Return Normally */
      WHILE @@TRANCOUNT > @n_starttcnt
         COMMIT TRAN
      RETURN
   END

END

GO