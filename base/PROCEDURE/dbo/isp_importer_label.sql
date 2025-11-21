SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_importer_label                                 */    
/* Creation Date: 17-Sep-2014                                           */    
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: 320446 - SG Prestige Importer Label                         */    
/*                                                                      */    
/* Called By: PB dw: r_dw_importer_label                                */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Ver.  Purposes                                  */    
/* 05-Jan-2015  NJOW01  1.0   320446-add filter by country code and     */
/*                            skugroup.                                 */
/* 30-Sep-2015  NJOW02  1.1   353964/356659 - change print conditon to  */
/*                            Orders.Userdefine01 = Y                   */
/* 24-Feb-2016  CSCHONG 1.2   Revise Field logic (CS01)                 */
/* 22-Mar-2018  CSCHONG 1.3   WMS-4311 - add lottable01 group by (CS02) */
/* 17-SEP-2020  CSCHONG 1.4   WMS-15207 revised field logic (CS03)      */
/* 07-Jan-2021  NJOW03  1.5   WMS-15811 lottable01 filtring by qty      */ 
/* 03-Mar-2021  NJOW04  1.6   Fix sku to 20 characters                  */
/************************************************************************/    
    
CREATE PROC [dbo].[isp_importer_label] (    
       @c_PickslipNo NVARCHAR(10),    
       @c_Sku NVARCHAR(20),
       @c_Qty INT = '0',   
       @c_Lottable01 NVARCHAR(18) = ''  --NJOW03
 )    
 AS    
 BEGIN    
   SET NOCOUNT ON   -- SQL 2005 Standard  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF      
   
   DECLARE @c_Orderkey NVARCHAR(10),
           @dt_ExpDate DATETIME,           
           @n_NoOfLabel INT,
           @n_Qty       INT,
           @n_Cnt       INT,
           @c_ColTitle  NVARCHAR(10)

   IF ISNUMERIC(@c_qty) = 1
      SET @n_Qty = CAST(@c_Qty AS INT)
   ELSE
      SET @n_Qty = 0
   
   CREATE TABLE #TMP_LABELS (ExpDate DATETIME NULL,coltitle NVARCHAR(10) NULL)
   
   SELECT TOP 1 @c_Orderkey = Orderkey
   FROM PICKHEADER(NOLOCK)
   WHERE PickHeaderkey = @c_Pickslipno
  
   /*CS02 Start*/
   
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT  SUM(PD.Qty), 
          --CS03 START
          -- CASE WHEN ISNULL(SKU.ShelfLife,0)=0 THEN NULL ELSE 
          --	             CASE WHEN SKU.BUSR6 IN ('GIVENCHY COSMETICS','GIVENCHY SKINCARE') THEN MAX(LA.Lottable04 ) - ISNULL(SKU.ShelfLife,0)
          --	             	ELSE MAX(LA.Lottable05) + ISNULL(SKU.ShelfLife,0) END END  --(CS01)
          --, CASE WHEN SKU.BUSR6 IN ('GIVENCHY COSMETICS','GIVENCHY SKINCARE') THEN 'MFG Date:' ELSE 'EXP Date: ' END  --(CS01)
         MAX(LA.Lottable04 ), 'EXP Date: '
        --CS03 END
   FROM  ORDERS O (NOLOCK)
   JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
   JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
   JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot 
   --JOIN STORER S (NOLOCK) ON O.ConsigneeKey = S.StorerKey
   WHERE O.OrderKey = @c_Orderkey 
   AND O.Userdefine01 = 'Y'  --NJOW02
   --AND S.susr1 = 'EXPLABEL'
   AND PD.Sku = @c_Sku
   --AND LEFT(O.ExternOrderKey,3) = 'SOR' 
   --AND S.ISOCntryCode = 'SG' --NJOW01
   AND SKU.SkuGroup = 'STOCK' 
   AND LA.Lottable01 = CASE WHEN ISNULL(@c_Lottable01,'') <> '' THEN @c_Lottable01 ELSE LA.Lottable01 END --NJOW03
   GROUP BY PD.Sku, ISNULL(SKU.ShelfLife,0),SKU.BUSR6,LA.lottable01           --CS02
   
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @n_NoOfLabel, @dt_ExpDate,   @c_ColTitle
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      SET @n_Cnt = 1--@@ROWCOUNT
      /*CS02 start remove this part*/
     /* IF @n_Qty > 0  
      BEGIN
         SET @n_NoOfLabel = @n_Qty
      END  */
	   /*CS02 End*/

      --NJOW03
   	  IF ISNULL(@c_Lottable01,'') <> '' AND @n_Qty > 0
   	     SET @n_NoOfLabel = @n_Qty

      WHILE @n_NoOfLabel > 0 AND @n_Cnt > 0
      BEGIN
         INSERT INTO #TMP_LABELS (ExpDate,coltitle) VALUES (@dt_ExpDate,@c_ColTitle)        --(CS01)
      	 SELECT @n_NoOfLabel = @n_NoOfLabel - 1
      END
      
      FETCH NEXT FROM CUR_RESULT INTO  @n_NoOfLabel, @dt_ExpDate,   @c_ColTitle
   END   
      
   SELECT * 
   FROM #TMP_LABELS    
END    

GO