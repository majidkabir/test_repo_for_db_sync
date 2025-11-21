SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/      
/* Store Procedure: isp_returnLabel_JP                                        */      
/* Creation Date: 31-DEC-2019                                                 */      
/* Copyright:                                                                 */      
/* Written by: CSCHONG                                                        */      
/*                                                                            */      
/* Purpose: For JP LIT datawindow: r_dw_return_label_JP                       */      
/*                                                                            */      
/*                                                                            */      
/* Called By:                                                                 */      
/*                                                                            */      
/* PVCS Version: 1.0                                                          */      
/*                                                                            */      
/* Version: 1.0                                                               */      
/*                                                                            */      
/* Data Modifications:                                                        */      
/*                                                                            */      
/* Updates:                                                                   */      
/* Date         Author    Ver.  Purposes                                      */      
/* 20200130     Grick     1.0   Select Top single result (G01)                */   
/* 20220421     CHONGCS   1.1   Devops Scripts Combine & WMS-19426 (CS01)     */   
/******************************************************************************/      
      
CREATE PROC [dbo].[isp_returnLabel_JP] (      
@c_receiptKey NVARCHAR(20)      
)      
AS      
      
BEGIN      
   SET NOCOUNT ON        
   SET QUOTED_IDENTIFIER OFF        
   SET ANSI_NULLS OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
         
      
   DECLARE @c_storerkey NVARCHAR(20)      
          ,@c_ErrMsg    NVARCHAR(250)      
      
CREATE TABLE #TEMPRTNLBLJP (      
 RowID        INT NOT NULL IDENTITY (1,1) PRIMARY KEY,      
 Storerkey    NVARCHAR(20) NULL,      
 receiptKey   NVARCHAR(20) NULL,      
 Loc          NVARCHAR(20) NULL,      
 SKU          NVARCHAR(20) NULL,      
 ErrMsg       NVARCHAR(250) NULL,      
 RecLineNo    NVARCHAR(10) NULL,      
)      
      
      
CREATE TABLE #TEMPPLOCJP (      
    RowID        INT NOT NULL IDENTITY (1,1) PRIMARY KEY,      
 Storerkey    NVARCHAR(20) NULL,      
 Loc          NVARCHAR(20) NULL,      
 SKU          NVARCHAR(20) NULL,      
 ErrMsg       NVARCHAR(250) NULL,      
 RecLineNo    NVARCHAR(10) NULL,      
)      
      
SET @c_storerkey = ''      
SET @c_ErrMsg = ''      
      
SELECT @c_storerkey = RH.STORERKEY      
FROM RECEIPT RH WITH (NOLOCK)      
WHERE RH.ReceiptKey = @c_receiptKey      
      
 IF @c_storerkey = 'HM'      
 BEGIN      
      
   IF EXISTS (select 1 from lotxlocxid lli (nolock)       
    join lotattribute la (nolock) on lli.lot = la.lot and lli.sku=la.sku      
    join RECEIPTDETAIL RD WITH (NOLOCK) ON lli.sku = RD.Sku and RD.Lottable02 = LA.lottable02      
    where RD.StorerKey = @c_storerkey      
    and lli.qty>0      
    and RD.ReceiptKey=@c_receiptKey)      
   BEGIN      
    INSERT INTO #TEMPRTNLBLJP (storerkey,receiptkey,loc,sku,errmsg,RecLineNo)      
    SELECT   RD.STORERKEY,RD.RECEIPTKEY,B.LOC,RD.SKU,'',RD.RECEIPTLINENUMBER     
    FROM RECEIPTDETAIL RD WITH (NOLOCK) 
    CROSS APPLY (SELECT TOP 1 LLI.SKU,LLI.LOC FROM LOTXLOCXID LLI (NOLOCK) --G01
    JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.LOT = LA.LOT AND LLI.SKU=LA.SKU 
    AND LLI.QTY>0 AND LLI.SKU = RD.SKU AND RD.LOTTABLE02 = LA.LOTTABLE02 AND LLI.QTY>0) B
    JOIN RECEIPT RH WITH (NOLOCK) ON RH.RECEIPTKEY = RD.RECEIPTKEY       
    WHERE RD.StorerKey = @c_storerkey      
    AND RD.ReceiptKey=@c_receiptKey        
  
      IF NOT EXISTS (SELECT 1 FROM  #TEMPRTNLBLJP)  
      BEGIN  
       SELECT @c_ErrMsg = description       
       FROM codelkup WITH (NOLOCK)      
       WHERE Listname='HMRLabel' and short ='Noti' and Long ='2' and storerkey =@c_storerkey      
        
       INSERT INTO #TEMPRTNLBLJP (storerkey,receiptkey,loc,sku,errmsg)      
       VALUES(@c_storerkey,@c_receiptKey,'','',@c_ErrMsg)    
      END     
   END
 END  --CS01 S
   ELSE IF @c_storerkey = 'FJ'      
   BEGIN      
      
   IF EXISTS (select 1 from lotxlocxid lli (nolock)       
    join lotattribute la (nolock) on lli.lot = la.lot and lli.sku=la.sku      
    join RECEIPTDETAIL RD WITH (NOLOCK) ON lli.sku = RD.Sku 
    where RD.StorerKey = @c_storerkey      
    and lli.qty>0      
    and la.Lottable03 = 'Good'      
    and RD.ReceiptKey=@c_receiptKey)      
   BEGIN      
    INSERT INTO #TEMPRTNLBLJP (storerkey,receiptkey,loc,sku,errmsg,RecLineNo)      
    --SELECT   RD.STORERKEY,RD.RECEIPTKEY,B.LOC,RD.SKU,'',RD.RECEIPTLINENUMBER     
    --FROM RECEIPTDETAIL RD WITH (NOLOCK) 
    --CROSS APPLY (SELECT TOP 1 LLI.SKU,LLI.LOC FROM LOTXLOCXID LLI (NOLOCK) --G01
    --JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.LOT = LA.LOT AND LLI.SKU=LA.SKU 
    --AND LLI.QTY>0 AND LLI.SKU = RD.SKU AND RD.LOTTABLE02 = LA.LOTTABLE02 AND LLI.QTY>0) B
    --JOIN RECEIPT RH WITH (NOLOCK) ON RH.RECEIPTKEY = RD.RECEIPTKEY       
    --WHERE RD.StorerKey = @c_storerkey      
    --AND RD.ReceiptKey=@c_receiptKey        

   SELECT   RD.STORERKEY,RD.RECEIPTKEY,B.LOC,RD.SKU,'',RD.RECEIPTLINENUMBER           
   FROM RECEIPTDETAIL RD WITH (NOLOCK)      
   CROSS APPLY (SELECT TOP 1 LLI.SKU,LLI.LOC FROM LOTXLOCXID LLI (NOLOCK) --G01      
                JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.LOT = LA.LOT AND LLI.SKU=LA.SKU       
                AND LLI.QTY>0 AND LLI.SKU = RD.SKU AND LA.LOTTABLE03='Good'
                AND LLI.QTY>0 --updated on V2.0
                ORDER by LLI.QTY DESC) B   --updated on V2.0    
    JOIN RECEIPT RH WITH (NOLOCK) ON RH.RECEIPTKEY = RD.RECEIPTKEY  
    WHERE RD.StorerKey = @c_storerkey AND RD.ReceiptKey=@c_receiptKey 
  
      IF NOT EXISTS (SELECT 1 FROM  #TEMPRTNLBLJP)  
      BEGIN  
       SELECT @c_ErrMsg = description       
       FROM codelkup WITH (NOLOCK)      
       WHERE Listname='HMRLabel' and short ='Noti' and Long ='2' and storerkey =@c_storerkey      
        
       INSERT INTO #TEMPRTNLBLJP (storerkey,receiptkey,loc,sku,errmsg)      
       VALUES(@c_storerkey,@c_receiptKey,'','',@c_ErrMsg)    
      END     
   END
  --Cs01 E      
   ELSE      
   BEGIN      
         
    SELECT @c_ErrMsg = description       
    FROM codelkup WITH (NOLOCK)      
    WHERE Listname='HMRLabel' and short ='Noti' and Long ='1' and storerkey =@c_storerkey      
       
    INSERT INTO #TEMPRTNLBLJP (storerkey,receiptkey,loc,sku,errmsg)      
    VALUES(@c_storerkey,@c_receiptKey,'','',@c_ErrMsg)      
   END      
 END      
 ELSE      
  BEGIN      
   IF EXISTS (select 1 from lotxlocxid lli (nolock)       
         join lotattribute la (nolock) on lli.lot = la.lot and lli.sku=la.sku      
         join RECEIPTDETAIL RD WITH (NOLOCK) ON lli.sku = RD.Sku and RD.Lottable02 = LA.lottable02      
         where RD.StorerKey = @c_storerkey      
         and lli.qty>0      
         and RD.ReceiptKey=@c_receiptKey)      
    BEGIN      
       INSERT INTO #TEMPRTNLBLJP (storerkey,receiptkey,loc,sku,errmsg,RecLineNo)      
       SELECT RD.STORERKEY,RD.RECEIPTKEY,B.LOC,RD.SKU,'H/F      : '+ISNULL(C.UDF01,''),RD.RECEIPTLINENUMBER     
       FROM RECEIPTDETAIL RD WITH (NOLOCK)   
       JOIN RECEIPT RH WITH (NOLOCK) ON RH.RECEIPTKEY = RD.RECEIPTKEY     
       CROSS APPLY (SELECT TOP 1 LLI.SKU,LLI.LOC FROM LOTXLOCXID LLI (NOLOCK) --G01
       JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.LOT = LA.LOT 
       AND LLI.SKU = RD.SKU AND RD.LOTTABLE02 = LA.LOTTABLE02 AND LLI.QTY>0 )  B
       JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME = 'COSLOCTYPE' AND C.STORERKEY = RH.STORERKEY AND C.CODE = LEFT(B.LOC,2)            
       WHERE RD.StorerKey = @c_storerkey      
       AND RD.ReceiptKey=@c_receiptKey         
  
       IF NOT EXISTS (SELECT 1 FROM  #TEMPRTNLBLJP)  
       BEGIN  
        SELECT @c_ErrMsg = description       
        FROM codelkup WITH (NOLOCK)      
        WHERE Listname='HMRLabel' and short ='Noti' and Long ='1' and storerkey =@c_storerkey      
        
        INSERT INTO #TEMPRTNLBLJP (storerkey,receiptkey,loc,sku,errmsg)      
        VALUES(@c_storerkey,@c_receiptKey,'','',@c_ErrMsg)    
       END  
    END  
    ELSE IF EXISTS (SELECT 1 FROM  PICKDETAIL PD (NOLOCK)       
     JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.Sku = PD.Sku AND OD.OrderLineNumber = PD.OrderLineNumber      
     JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON RD.storerkey = PD.storerkey      
     AND RD.ExternReceiptKey = OD.ExternOrderKey AND RD.Sku = PD.Sku       
     WHERE RD.ReceiptKey=@c_receiptKey)            
    BEGIN      
        INSERT INTO #TEMPRTNLBLJP (storerkey,receiptkey,loc,sku,errmsg,RecLineNo)      
        SELECT DISTINCT RD.Storerkey,RD.receiptkey,PD.loc,RD.Sku,'H/F      : '+ISNULL(C.UDF01,''),RD.ReceiptLineNumber      
        FROM  PICKDETAIL PD (NOLOCK)       
        JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.Sku = PD.Sku AND OD.OrderLineNumber = PD.OrderLineNumber      
        JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON RD.storerkey = PD.storerkey      
        AND RD.ExternReceiptKey = OD.ExternOrderKey AND RD.Sku = PD.Sku   AND RD.EXTERNLINENO=OD.EXTERNLINENO  
        JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME = 'COSLOCTYPE' AND C.Storerkey = PD.Storerkey AND C.Code = LEFT(PD.loc,2)      
        WHERE RD.ReceiptKey=@c_receiptKey      
        --ORDER BY RD.receiptlinenumber      
        
         IF NOT EXISTS (SELECT 1 FROM  #TEMPRTNLBLJP)  
         BEGIN  
           SELECT @c_ErrMsg = description       
           FROM codelkup WITH (NOLOCK)      
           WHERE Listname='HMRLabel' and short ='Noti' and Long ='2' and storerkey =@c_storerkey      
        
           INSERT INTO #TEMPRTNLBLJP (storerkey,receiptkey,loc,sku,errmsg)      
           VALUES(@c_storerkey,@c_receiptKey,'','',@c_ErrMsg)    
         END  
     END  
     ELSE      
     BEGIN      
      
       SELECT @c_ErrMsg = description       
       FROM codelkup WITH (NOLOCK)      
       WHERE Listname='HMRLabel' and short ='Noti' and Long ='1' and storerkey =@c_storerkey      
        
       INSERT INTO #TEMPRTNLBLJP (storerkey,receiptkey,loc,sku,errmsg)      
       VALUES(@c_storerkey,@c_receiptKey,'','',@c_ErrMsg)      
     END       
  END       
         
 SELECT DISTINCT TLJP.storerkey,TLJP.receiptkey,TLJP.sku,TLJP.loc,      
 ISNULL(TLJP.errmsg,'')AS ErrMsg,TLJP.RowID as Seqno,      
 TLJP.RecLineNo    
 from #TEMPRTNLBLJP TLJP          
 where receiptKey = @c_receiptKey          
 ORDER BY TLJP.RecLineNo      
      
    
END   


GO