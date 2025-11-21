SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
    
      
/************************************************************************/        
/* Stored Procedure: isp_GetReceiptCaseID                               */        
/* Creation Date: 24-Feb-2015                                           */        
/* Copyright: IDS                                                       */        
/* Written by: CSCHONG                                                  */        
/*                                                                      */        
/* Purpose: SOS#333816 - isp_GetReceiptCaseID                           */        
/*                                                                      */        
/* Called By: r_dw_Receipt_case_label_rdt                               */         
/*                                                                      */        
/* Parameters:                                                          */        
/*                                                                      */        
/* PVCS Version: 1.0                                                    */        
/*                                                                      */        
/* Version: 1.0                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author    Ver.  Purposes                                */     
/* 2015-07-31   CSCHONG   1.0   Fix caseqty to 4 digit (CS01)           */       
/************************************************************************/        
        
CREATE PROC [dbo].[isp_GetReceiptCaseID] (        
   @c_Storerkey NVARCHAR(15),      
   @c_SKU       NVARCHAR(20),        
   @c_CaseQty   NVARCHAR(5) ,      
   @c_Copy      NVARCHAR(3)        
)        
AS        
BEGIN        
        
   SET NOCOUNT ON        
   SET QUOTED_IDENTIFIER OFF        
   SET ANSI_NULLS OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
           
  DECLARE      
   @n_keycount     INT,          
   @c_skudescr     NVARCHAR(60),        
   @c_caseid       NVARCHAR(13),        
   @b_debug        INT,      
   @c_errmsg       NVARCHAR(255),        
   @b_success      INT,        
   @n_err          INT,      
   @n_copy         INT,      
   @c_GetCaseQty   NVARCHAR(5),      
   @c_addwho      NVARCHAR(20),      
   @n_MaxRec      INT,      
   @n_StartRec    INT         
        
      
   SET @n_copy=convert(int,@c_copy)      
   SET @c_addwho=''      
      
   SET @c_GetCaseQty = Floor(convert(int,@c_CaseQty) / @n_copy)      
      
   CREATE TABLE #tempreccase       
   ( Sku NVARCHAR(20) NULL,        
     caseid NVARCHAR(12) NULL,      
     skudescr NVARCHAR(60) NULL,      
     caseqty  NVARCHAR(5) NULL,      
     Addwho   NVARCHAR(15) NULL,      
     RecDate  NVARCHAR(10) NULL)       
      
      
        
  SET @n_MaxRec = 2      
  --SELECT @b_success = 1, @c_errmsg='', @n_err=0         
 SELECT @n_keycount = KeyCount        
 FROM   NCounter WITH (NOLOCK)        
 WHERE  KeyName = 'JACKW_RECCaseID'       
      
  SELECT @c_skudescr = descr      
  FROM   SKU WITH (NOLOCK)      
  WHERE Storerkey=@c_storerkey      
  AND SKU = @c_sku      
      
  SELECT TOP 1 @c_addwho = addwho      
  FROM RDT.RDTPrintJob WITH (NOLOCK)      
  WHERE datawindow = 'r_dw_receipt_case_label_rdt'      
  AND Parm1 = @c_Storerkey       
  AND Parm2= @c_SKU      
  AND Parm3= @c_CaseQty      
  AND Parm4= @c_Copy      
  AND JobStatus < '9'      
  ORDER BY 1 desc      
      
  WHILE @n_copy <> 0      
   BEGIN      
   SET @n_StartRec = 1      
   SET @n_keycount = @n_keycount + 1       
   SET @c_caseid = convert(nvarchar(8),@n_keycount) --+ RIGHT('000'+CAST(@c_GetCaseQty AS VARCHAR(3)),3)      
      
   --SELECT @c_caseid      
   WHILE @n_startRec <=@n_MaxRec       
   BEGIN      
   INSERT INTO #Tempreccase(sku,caseid,skudescr,caseqty,addwho,recdate)      
   VALUES(@c_sku,@c_caseid,@c_skudescr,RIGHT('0000'+ISNULL(@c_GetCaseQty,''),4),@c_addwho,convert(nvarchar(10),getdate(),126))           
   SET @n_startRec = @n_startRec + 1      
   END      
      
   SET @n_copy = @n_copy - 1      
   --SET @n_keycount = @n_keycount + 1      
      
   UPDATE NCounter       
   Set KeyCount = @n_keycount      
   WHERE KeyName = 'JACKW_RECCaseID'       
      
   IF @@ERROR <> 0         
  BEGIN        
   --SELECT @n_continue = 3        
   SELECT @n_err = 63501        
   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert / Update Into NCounter Failed. (isp_GetReceiptCaseID)"        
  END      
      
   END      
        
select sku,caseid,skudescr,caseqty,addwho,recdate from #Tempreccase      
      
END

GO