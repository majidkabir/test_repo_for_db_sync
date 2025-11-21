SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_load_assign_xdockasn                            */  
/* Creation Date: 26-Mar-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-4124 TH REV Loadplan assigne Xdock ASN                   */  
/*                                                                       */  
/* Called By: wave                                                       */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */ 
/*************************************************************************/   

CREATE PROCEDURE [dbo].[isp_load_assign_xdockasn]      
  @c_Loadkey            NVARCHAR(10)  
 ,@c_receiptkeys        NVARCHAR(MAX) = ''
 ,@c_ProceedWithWarning NVARCHAR(1) = 'N'
 ,@n_WarningNo          INT = 0       OUTPUT
 ,@b_Success            INT           OUTPUT  
 ,@n_err                INT           OUTPUT  
 ,@c_errmsg             NVARCHAR(250) OUTPUT  
 AS  
 BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
    
    DECLARE @n_continue int,    
            @n_starttcnt int,         -- Holds the current transaction count  
            @n_debug int,
            @n_cnt int
            
    SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0, @n_debug = 0
    
    IF @c_ProceedWithWarning <> 'Y'
       SET @n_Warningno = 0

    DECLARE @c_Sku NVARCHAR(20)
           ,@n_OrderQty INT
           ,@n_ASNQty INT
           ,@n_XDOverQtyTolerancePerc DECIMAL(10,2)           
           
    SET @n_XDOverQtyTolerancePerc = 1
           
    SELECT @n_XDOverQtyTolerancePerc = CASE WHEN ISNUMERIC(NSQLValue) = 1 THEN CAST(NSQLValue AS DECIMAL(10,2)) ELSE 1 END 
    FROM NSQLCONFIG (NOLOCK)
    WHERE Configkey = 'XDOverQtyTolerancePerc'
    
    IF ISNULL(@n_XDOverQtyTolerancePerc, 0) = 0
       SET @n_XDOverQtyTolerancePerc = 1
                                     
    IF @n_continue IN(1,2)
    BEGIN
       SELECT DISTINCT Colvalue AS Receiptkey
       INTO #TMP_RECEIPT 
       FROM dbo.fnc_DelimSplit(',', @c_receiptkeys)
       WHERE ISNULL(Colvalue,'') <> ''
       
       SELECT RD.Storerkey, RD.Sku, SUM(RD.QtyExpected) AS Qty
       INTO #TMP_RECEIPTSKU       
       FROM RECEIPT R (NOLOCK) 
       JOIN RECEIPTDETAIL RD(NOLOCK) ON R.Receiptkey = RD.Receiptkey       
       JOIN #TMP_RECEIPT TR ON R.Receiptkey = TR.Receiptkey
       WHERE R.Status = '0' 
       AND ISNULL(R.Userdefine03,'') = '' 
       GROUP BY RD.Storerkey, RD.Sku
       
       SELECT @c_SKU = '', @n_OrderQty = 0, @n_ASNQty = 0 

       SELECT TOP 1 @c_Sku = OD.SKU, 
                    @n_OrderQty = SUM(OD.OpenQty),
                    @n_ASNQty  = ISNULL(TRS.Qty,0)
       FROM ORDERS O(NOLOCK)
       JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
       LEFT JOIN #TMP_RECEIPTSKU TRS ON OD.Storerkey = TRS.Storerkey AND OD.Sku = TRS.Sku
       WHERE O.Loadkey = @c_Loadkey
       GROUP BY OD.SKU, ISNULL(TRS.Qty,0)
       HAVING SUM(OD.OpenQty) > ISNULL(TRS.Qty,0) 
              
       IF @@ROWCOUNT > 0 
       BEGIN
       	   SELECT @n_continue = 3  
           SELECT @n_err = 81010  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': SKU: ' + RTRIM(@c_Sku) + ' Stock not enough. Order Qty: ' + RTRIM(CAST(@n_OrderQty AS NVARCHAR)) + ' ASN Qty: ' +  RTRIM(CAST(@n_ASNQty AS NVARCHAR)) + ' (isp_load_assign_xdockasn)'         
       END
       ELSE IF @c_ProceedWithWarning <> 'Y' OR @n_WarningNo < 1
       BEGIN
          SELECT @c_SKU = '', @n_OrderQty = 0, @n_ASNQty = 0 
        
          SELECT TOP 1 @c_Sku = OD.SKU, 
                       @n_OrderQty = SUM(OD.OpenQty),
                       @n_ASNQty  = ISNULL(TRS.Qty,0)
          FROM ORDERS O(NOLOCK)
          JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
          LEFT JOIN #TMP_RECEIPTSKU TRS ON OD.Storerkey = TRS.Storerkey AND OD.Sku = TRS.Sku
          WHERE O.Loadkey = @c_Loadkey
          GROUP BY OD.SKU, ISNULL(TRS.Qty,0)
          HAVING ISNULL(TRS.Qty,0) > (SUM(OD.OpenQty) * @n_XDOverQtyTolerancePerc)
          
          IF @@ROWCOUNT > 0 
          BEGIN
          	  SELECT @n_continue = 3  
          	  SELECT @n_WarningNo = 1
              SELECT @c_errmsg='SKU: ' + RTRIM(@c_Sku) + ' Over receive. Order Qty: ' + RTRIM(CAST(@n_OrderQty AS NVARCHAR)) + ' ASN Qty: ' +  RTRIM(CAST(@n_ASNQty AS NVARCHAR)) + '. Do you still want to proceed ?'         
          END              	
       END                                   
    END           

    IF @n_continue IN(1,2)
    BEGIN    	
    	 UPDATE RECEIPT WITH (ROWLOCK)
    	 SET Userdefine03 = @c_Loadkey
    	 WHERE Receiptkey IN (SELECT R.Receiptkey
                            FROM RECEIPT R (NOLOCK) 
                            JOIN #TMP_RECEIPT TR ON R.Receiptkey = TR.Receiptkey
                            WHERE R.Status = '0' 
                            AND ISNULL(R.Userdefine03,'') = '') 
       
       SET @n_err = @@ERROR
       
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 81020  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPT Table Failed. (isp_load_assign_xdockasn)'         
      END                           
    END
               
RETURN_SP:

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
       IF @n_WarningNo = 0
       BEGIN
          execute nsp_logerror @n_err, @c_errmsg, "isp_load_assign_xdockasn"  
          RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
       END
       RETURN  
    END  
    ELSE  
    BEGIN     	 
       SELECT @b_success = 1
       SELECT @n_WarningNo = 0  
       WHILE @@TRANCOUNT > @n_starttcnt  
       BEGIN  
          COMMIT TRAN  
       END  
       RETURN  
    END     
 END --sp end

GO