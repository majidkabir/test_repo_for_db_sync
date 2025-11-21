SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* SP: ispPopulateTOASN_VFCDC                                           */  
/* Creation Date: 28.Aug.2013                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Shong                                                    */  
/*                                                                      */  
/* Purpose: Populate ASN Detail from ORDERS for IDSCN CNA               */  
/*                                                                      */  
/* Usage: Use For Warehouse transfering                                 */  
/*                                                                      */  
/* Called By: Backend Job                                               */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */   
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 13-May-2014  SHONG  1.1    Change AltSKU to SKU                      */
/* 27-May-2014  TKLIM  1.2    Added Lottables 06-15                   */
/************************************************************************/  
 
CREATE PROC [dbo].[ispPopulateTOASN_VFCDC]   
   @c_MBOLKey  NVARCHAR(10),  
   @b_Success  INT OUTPUT ,  
   @n_Err      INT OUTPUT,  
   @c_ErrMsg   NVARCHAR(255) OUTPUT
AS
BEGIN
    
   SET NOCOUNT ON  
  
   DECLARE @c_SKU                   NVARCHAR(20),  
           @c_PackKey               NVARCHAR(10),  
           @c_UOM                   NVARCHAR(5),  
           @c_StorerKey             NVARCHAR(15),  
           @c_Facility              NVARCHAR(5),  
           @c_OrderKey              NVARCHAR(10),
           @c_ContainerKey          NVARCHAR(20),
           @c_PrevContainerKey      NVARCHAR(20),
           @c_CaseID                NVARCHAR(20),
           @c_PickSlipNo            NVARCHAR(10),
           @c_VehicleNo             NVARCHAR(20),
           @c_ToStorerKey           NVARCHAR(15)
  
   DECLARE @c_Lottable01            NVARCHAR(18),  
           @c_Lottable02            NVARCHAR(18),  
           @c_Lottable03            NVARCHAR(18),
           @c_DefaultLottable03     NVARCHAR(18),  
           @c_Lottable06            NVARCHAR(30),
           @c_Lottable07            NVARCHAR(30),
           @c_Lottable08            NVARCHAR(30),
           @c_Lottable09            NVARCHAR(30),
           @c_Lottable10            NVARCHAR(30),
           @c_Lottable11            NVARCHAR(30),
           @c_Lottable12            NVARCHAR(30),
           @d_Lottable13            DATETIME,
           @d_Lottable14            DATETIME,
           @d_Lottable15            DATETIME,
           @n_StartTCnt             INT  
  
   DECLARE @c_NewReceiptKey         NVARCHAR(10),  
           @c_ReceiptLine           NVARCHAR(5),  
           @n_LineNo                int,  
           @c_OrderType             NVARCHAR(10),  
           @c_ToFacility            NVARCHAR(5),  
           @n_ExpectedQty           int,  
           @n_Qty                   int,  
           @c_TOLOC                 NVARCHAR(30),
           @c_NewSKU                NVARCHAR(20)   
      
   DECLARE @n_continue        INT  
  
   SELECT @n_continue = 1, @b_Success = 1, @n_err = 0  
   SET @n_StartTCnt = @@TRANCOUNT
   BEGIN TRAN
   
   SET @c_PrevContainerKey = ''
   
   DECLARE C_CaseID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT Ctn.ContainerKey, PltDet.CaseId, Ctn.OtherReference, plt.StorerKey 
   FROM MBOL M (NOLOCK)
   JOIN CONTAINER Ctn ON Ctn.MbolKey = M.MbolKey
   JOIN CONTAINERDETAIL CtnDet WITH (NOLOCK) ON CtnDet.ContainerKey = Ctn.ContainerKey
   JOIN PALLET Plt WITH (NOLOCK) ON Plt.PalletKey = CtnDet.PalletKey
   JOIN PALLETDETAIL PltDet WITH (NOLOCK) ON PltDet.PalletKey = Plt.PalletKey 
   WHERE M.MbolKey = @c_MBOLKey 
   AND M.[Status] = '9'
   ORDER BY Ctn.ContainerKey, PltDet.CaseId 
   
   OPEN C_CaSeId 
   
   FETCH NEXT FROM C_CaseID INTO @c_ContainerKey, @c_CaseID, @c_VehicleNo, @c_StorerKey 
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT TOP 1 
         @c_PickSlipNo = pd.PickSlipNo 
      FROM PackDetail pd WITH (NOLOCK)
      WHERE pd.LabelNo = @c_CaseID
      
      SELECT @c_OrderKey = ph.OrderKey 
      FROM PackHeader ph WITH (NOLOCK)
      WHERE ph.PickSlipNo = @c_PickSlipNo
      
      SELECT @c_Facility = o.Facility, 
             @c_OrderType = o.[Type] 
      FROM ORDERS o (NOLOCK)
      WHERE o.OrderKey = @c_OrderKey
               
      IF @c_ContainerKey <> @c_PrevContainerKey 
      BEGIN
         
         SET @c_TOLOC = ''
         SELECT @c_TOLOC = Userdefine04 
         FROM FACILITY f WITH (NOLOCK)
         WHERE f.Facility = @c_Facility
         
         IF ISNULL(RTRIM(@c_TOLOC),'') = ''  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526     
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+
                    ': Userdefine04 [To Location] NOT Setup in Facility ' + 
                    ISNULL(RTRIM(@c_Facility),'') + 
                    ' ! (ispPopulateTOASN_VFCDC)' 
            GOTO QUIT_SP  
         END     
                  
         SET @c_ToFacility = ''
         SET @c_ToStorerKey = ''
         SELECT @c_ToFacility = S.SUSR4, 
                @c_ToStorerKey = S.SUSR2 
         FROM STORER s (NOLOCK)
         WHERE s.StorerKey = @c_StorerKey

         IF ISNULL(RTRIM(@c_ToFacility),'') = '' OR ISNULL(RTRIM(@c_ToStorerKey),'') = ''
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526     
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+
                    ': SUSR4 [To Facility] OR SUSR2 [To Storer] Is NOT Setup in Storer ' + 
                    ISNULL(RTRIM(@c_StorerKey),'') + 
                    ' ! (ispPopulateTOASN_VFCDC)'  
            GOTO QUIT_SP  
         END         
         
         SET @c_DefaultLottable03 = ''
         SELECT @c_DefaultLottable03 = F.Userdefine03
         FROM FACILITY f WITH (NOLOCK)
         WHERE f.Facility = @c_ToFacility 
         
         IF ISNULL(RTRIM(@c_DefaultLottable03),'') = ''  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526     
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+
                    ': Userdefine03 [Default Lottable03] NOT Setup in Facility ' + 
                    ISNULL(RTRIM(@c_ToFacility),'') + 
                    ' ! (ispPopulateTOASN_VFCDC)'  
            GOTO QUIT_SP  
         END             
         --SELECT @c_Facility '@c_Facility', @c_ToFacility '@c_ToFacility', @c_TOLOC '@c_TOLOC', @c_OrderKey '@c_OrderKey', 
         --@c_CaseID '@c_CaseID', @c_PickSlipNo '@c_PickSlipNo', @c_ContainerKey '@c_ContainerKey'

          -- get next receipt key  
          SELECT @b_Success = 0  
          EXECUTE nspg_GetKey  
                  'RECEIPT'  
                  , 10  
                  , @c_NewReceiptKey OUTPUT  
                  , @b_Success OUTPUT  
                  , @n_Err OUTPUT  
                  , @c_ErrMsg OUTPUT  
            
          IF @b_Success = 1  
          BEGIN  
             INSERT INTO RECEIPT (ReceiptKey, ExternReceiptKey, VehicleNumber, StorerKey, 
                                  RecType, Facility, DocType)  
             VALUES (@c_NewReceiptKey, @c_ContainerKey, @c_VehicleNo, @c_ToStorerKey, 
                    @c_OrderType, @c_ToFacility, 'A')  
          END  
          ELSE  
          BEGIN  
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526     
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+
                     ': Generate Receipt Key Failed! (ispPopulateTOASN_VFCDC)' + ' ( ' + 
                     ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
             GOTO QUIT_SP  
          END         
          
          SET @c_PrevContainerKey = @c_ContainerKey   
          SET @n_LineNo = 1
      END
      
      DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.SKU, LA.Lottable01, LA.Lottable02, SUM(Qty),
            LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10,
            LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15
      FROM PICKDETAIL PD WITH (NOLOCK) 
      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON PD.Lot = LA.Lot 
      WHERE DropID = @c_CaseID 
      GROUP BY PD.SKU, LA.Lottable01, LA.Lottable02,
            LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10,
            LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15
      OPEN CUR_PICKDETAIL 
      
      FETCH NEXT FROM CUR_PICKDETAIL INTO 
                     @c_SKU, @c_Lottable01, @c_Lottable02, @n_ExpectedQty,
                     @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                     @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
          SET @c_ReceiptLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)  
          
          SET @c_UOM = ''
          SET @c_PackKey = ''
          SET @c_NewSKU = ''
          SELECT @c_UOM = PK.PackUOM3, 
                 @c_PackKey = PK.PackKey, 
                 @c_NewSKU  = SKU.Sku
          FROM PACK PK WITH (NOLOCK) 
          JOIN SKU WITH (NOLOCK) ON SKU.PackKey = PK.PackKey 
          WHERE SKU.StorerKey = @c_ToStorerKey
          AND   SKU.SKU = @c_SKU
          
         IF ISNULL(RTRIM(@c_UOM),'') = '' OR ISNULL(RTRIM(@c_PackKey),'') = '' OR ISNULL(RTRIM(@c_NewSKU),'') = ''
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526     
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+
                    ': SKU/Pack UOM/Pack Key not found for SKU ' + 
                    ISNULL(RTRIM(@c_SKU),'') + 
                    ' ! (ispPopulateTOASN_VFCDC)'  
            GOTO QUIT_SP  
         END     
                   
                        
          INSERT INTO RECEIPTDETAIL (ReceiptKey,   ReceiptLineNumber,   ExternReceiptKey,   
                                    ExternLineNo,  StorerKey,           SKU,   
                                    QtyExpected,   QtyReceived,  
                                    UOM,           PackKey,       ToLoc,         BeforeReceivedQty,
                                    Lottable01,    Lottable02,    Lottable03,    Lottable04,    Lottable05,           
                                    Lottable06,    Lottable07,    Lottable08,    Lottable09,    Lottable10,
                                    Lottable11,    Lottable12,    Lottable13,    Lottable14,    Lottable15)  
          VALUES        (@c_NewReceiptKey, @c_ReceiptLine,   @c_ContainerKey,  
                         '',               @c_ToStorerKey,   @c_NewSKU,  
                         ISNULL(@n_ExpectedQty,0),   0,    
                         @c_UOM,           @c_Packkey,       @c_TOLOC,  0,
                         @c_Lottable01,    @c_Lottable02,    @c_DefaultLottable03,  NULL,             NULL, 
                         @c_Lottable06,    @c_Lottable07,    @c_Lottable08,         @c_Lottable09,    @c_Lottable10,
                         @c_Lottable11,    @c_Lottable12,    @d_Lottable13,         @d_Lottable14,    @d_Lottable15)                              
                                                
         SELECT @n_LineNo = @n_LineNo + 1  

         FETCH NEXT FROM CUR_PICKDETAIL INTO 
                        @c_SKU, @c_Lottable01, @c_Lottable02, @n_ExpectedQty,
                        @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                        @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
      END

      CLOSE CUR_PICKDETAIL 
      DEALLOCATE CUR_PICKDETAIL
      IF NOT EXISTS(SELECT 1 FROM RECEIPTDETAIL r WITH (NOLOCK)
                    WHERE r.ReceiptKey = @c_NewReceiptKey)
      BEGIN  
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63601     
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+
                  ': No Receipt Detail Generate! (ispPopulateTOASN_VFCDC)' + ' ( ' + 
                  ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
          GOTO QUIT_SP  
      END 

      --SELECT @c_CaseID '@c_CaseID', @c_ContainerKey '@c_ContainerKey',  
      --       @c_StorerKey '@c_StorerKey',     @c_SKU '@c_SKU',  @n_ExpectedQty '@n_ExpectedQty', @c_TOLOC '@c_TOLOC',
      --       @c_PickSlipNo '@c_PickSlipNo'
             
      DECLARE CUR_PackDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT StorerKey, SKU, SUM(Qty)
      FROM PackDetail pd WITH (NOLOCK) 
      WHERE pd.StorerKey = @c_StorerKey
      AND   pd.LabelNo = @c_CaseID 
      AND   pd.PickSlipNo = @c_PickSlipNo 
      GROUP BY StorerKey, SKU
      
      OPEN CUR_PackDetail 
      
      FETCH NEXT FROM Cur_PackDetail INTO @c_StorerKey, @c_SKU, @n_Qty 
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         --SELECT @c_ToStorerKey '@c_ToStorerKey', @c_NewSKU '@c_NewSKU'
         
         SET @c_NewSKU = ''
         SELECT @c_NewSKU  = SKU.Sku
         FROM SKU WITH (NOLOCK) 
         WHERE SKU.StorerKey = @c_ToStorerKey
         AND   SKU.SKU = @c_SKU
          
         IF ISNULL(RTRIM(@c_NewSKU),'') = ''
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526     
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+
                    ': Alt SKU not found In SKU Master. SKU: ' + 
                    ISNULL(RTRIM(@c_SKU),'') + ' Storer: ' + ISNULL(RTRIM(@c_ToStorerKey),'') +
                    ' ! (ispPopulateTOASN_VFCDC)'  
            GOTO QUIT_SP  
         END   
                  
         INSERT INTO UCC (UCCNo,Storerkey, SKU, qty, Sourcekey, Sourcetype, ExternKey)
         VALUES(@c_CaseID, @c_ToStorerKey, @c_NewSKU, @n_Qty, @c_NewReceiptKey, 'Order', @c_ContainerKey)
         
         FETCH NEXT FROM Cur_PackDetail INTO @c_StorerKey, @c_SKU, @n_Qty
      END
      CLOSE CUR_PackDetail 
      DEALLOCATE CUR_PackDetail      
      
      FETCH NEXT FROM C_CaseID INTO @c_ContainerKey, @c_CaseID, @c_VehicleNo, @c_StorerKey  
   END
   CLOSE C_CaseID
   DEALLOCATE C_CaseID

QUIT_SP:   
   IF @n_continue = 3 -- Error Occured - Process And Return
   BEGIN
       SET @b_Success = 0
       
       IF @@TRANCOUNT = 1
       AND @@TRANCOUNT >= @n_starttcnt
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
       EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_VFCDC' 
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
END -- if continue = 1 or 2 001  

GO