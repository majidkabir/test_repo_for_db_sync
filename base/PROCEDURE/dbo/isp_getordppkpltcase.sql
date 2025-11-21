SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: isp_GetOrdPPKPltCase                               */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by: YTWan                                                    */    
/*                                                                      */    
/* Purpose: SOS#238874. Orders Analytics                                */    
/*                                                                      */    
/* Called By: isp_AllocatedSummary                                      */     
/*                                                                      */    
/* Parameters: (Input)  Orderkey, externorderkey, consigneekey          */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver. Purposes                                 */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length     */    
/************************************************************************/    
CREATE PROCEDURE [dbo].[isp_GetOrdPPKPltCase]  
      @c_Orderkey       NVARCHAR(10)  
   ,  @c_ExternOrderkey NVARCHAR(50)=''   --tlting_ext
   ,  @c_ConsigneeKey   NVARCHAR(15)='' 
   ,  @n_TotalCarton    INT=0 OUTPUT   
   ,  @n_TotalPallet    INT=0 OUTPUT   
   ,  @n_TotalLoose     INT=0 OUTPUT 
   ,  @n_TotalCases     INT=0 OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON    
   SET ANSI_DEFAULTS OFF      
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    



   DECLARE  @n_Continue    INT  
         ,  @n_Transcount  INT  
         ,  @c_Storerkey   NVARCHAR(15)
         ,  @c_Sku         NVARCHAR(20)  

         ,  @n_QTY         INT  
         ,  @n_Pallet      DECIMAL (15,5)  
         ,  @n_CaseCnt     DECIMAL (15,5)   

         ,  @n_TotalBOMQty INT  
         ,  @n_RemainQty   INT 
         ,  @n_FP          INT 
         ,  @n_CS          INT 
         ,  @n_PC          INT 
         ,  @n_Cases       INT

   CREATE TABLE #TMP_ORDDET  
      ( 
            Rowid          INT IDENTITY(1 ,1)  
         ,  Storerkey      NVARCHAR(15)          NULL  
         ,  Sku            NVARCHAR(20)          NULL      
         ,  Qty            INT                  NULL
         ,  OpenQty        INT                  NULL
         ,  Pallet         DECIMAL (15,5)       NULL
         ,  CaseCnt        DECIMAL (15,5)       NULL

      )    

   SET @n_TotalCarton= 0 
   SET @n_TotalPallet= 0
   SET @n_TotalLoose = 0 
   SET @n_TotalCases = 0  

   SET @n_continue   = 1     
   SET @n_Transcount = @@TRANCOUNT    

   SET @c_Storerkey  = ''  
   SET @c_Sku        = ''
   SET @n_QTY        = 0
   SET @n_Pallet     = 0.0
   SET @n_CaseCnt    = 0.0

   SET @n_TotalBOMQty= 0
   SET @n_RemainQty  = 0
   SET @n_FP         = 0  
   SET @n_CS         = 0   
   SET @n_PC         = 0 
   SET @n_Cases      = 0 


   IF @n_continue=1 OR @n_continue=2  
   BEGIN  
      INSERT INTO #TMP_ORDDET ( Storerkey, Sku, Qty, Pallet, Casecnt)
      SELECT ISNULL(RTRIM(ORDERS.Storerkey),'')
            ,ISNULL(RTRIM(ORDERDETAIL.Lottable03),'')
            ,ISNULL(SUM(ORDERDETAIL.OpenQty),0)
            ,CASE WHEN RTRIM(ORDERDETAIL.Lottable03) = '' OR ORDERDETAIL.Lottable03 IS NULL THEN ISNULL(PACK.Pallet,0) ELSE ISNULL(PLP.Pallet,0) END
            ,CASE WHEN RTRIM(ORDERDETAIL.Lottable03) = '' OR ORDERDETAIL.Lottable03 IS NULL THEN ISNULL(PACK.CaseCnt,0) ELSE ISNULL(CSP.CaseCnt,0) END
      FROM ORDERS WITH (NOLOCK)
      JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
      JOIN SKU WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey) AND (ORDERDETAIL.Sku = SKU.Sku)
      JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
      LEFT JOIN UPC PL WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = PL.Storerkey) AND (ORDERDETAIL.Lottable03 = PL.Sku)
                                     AND(PL.UOM = 'PL')
      LEFT JOIN PACK PLP WITH (NOLOCK) ON (PL.Packkey = PLP.Packkey)
      LEFT JOIN UPC CS WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = CS.Storerkey) AND (ORDERDETAIL.Lottable03 = CS.Sku)
                                     AND(CS.UOM = 'CS')
      LEFT JOIN PACK CSP WITH (NOLOCK) ON (CS.Packkey = CSP.Packkey)
      WHERE ORDERS.Orderkey = @c_Orderkey
        AND (ORDERS.Externorderkey= CASE WHEN ISNULL(@c_ExternOrderkey ,'')='' THEN ORDERS.Externorderkey ELSE @c_ExternOrderkey END )   
        AND (ORDERS.Consigneekey= CASE WHEN ISNULL(@c_ConsigneeKey ,'')='' THEN ORDERS.Consigneekey ELSE @c_ConsigneeKey END ) 

      GROUP BY ISNULL(RTRIM(ORDERS.Storerkey),'')
            ,  ISNULL(RTRIM(ORDERDETAIL.Lottable03),'')
            ,  CASE WHEN RTRIM(ORDERDETAIL.Lottable03) = '' OR ORDERDETAIL.Lottable03 IS NULL THEN ISNULL(PACK.Pallet,0) ELSE ISNULL(PLP.Pallet,0) END
            ,  CASE WHEN RTRIM(ORDERDETAIL.Lottable03) = '' OR ORDERDETAIL.Lottable03 IS NULL THEN ISNULL(PACK.CaseCnt,0) ELSE ISNULL(CSP.CaseCnt,0) END
 
      DECLARE CUR_PrePackQty  CURSOR LOCAL FAST_FORWARD READ_ONLY   
      FOR  
         SELECT T.Storerkey  
               ,T.Sku  
               ,T.Qty  
               ,T.Pallet  
               ,T.Casecnt
         FROM   #TMP_ORDDET T  
          
        OPEN CUR_PrePackQty  
          
        FETCH NEXT FROM CUR_PrePackQty INTO @c_storerkey, @c_sku, @n_QTY, @n_Pallet, @n_CaseCnt                                   
          
        WHILE @@FETCH_STATUS<>-1  
        BEGIN  
            IF @c_Sku = ''  
            BEGIN
               SET @n_TotalBOMQty = 1
            END
            ELSE
            BEGIN
               SELECT @n_TotalBOMQty = SUM(BOM.Qty)
               FROM BillOfMaterial BOM WITH (NOLOCK)
               WHERE Storerkey = @c_Storerkey
               AND   Sku = @c_Sku
            END

            IF @n_Pallet > 0 
            BEGIN 
               SET @n_FP = @n_QTY/(@n_TotalBOMQty*@n_Pallet)
               SET @n_RemainQty = @n_QTY %(@n_TotalBOMQty*@n_Pallet)

            END 
            ELSE
            BEGIN
               SET @n_RemainQty = @n_QTY
            END
           
            IF @n_CaseCnt > 0
            BEGIN 
               SET @n_Cases = @n_QTY / (@n_TotalBOMQty*@n_CaseCnt) 
               SET @n_CS = @n_RemainQty / (@n_TotalBOMQty*@n_CaseCnt)
               SET @n_PC = @n_RemainQty % (@n_TotalBOMQty*@n_CaseCnt)  

            END
            ELSE
            BEGIN
               SET @n_PC = @n_RemainQty
            END

            SET @n_TotalPallet = @n_TotalPallet + @n_FP
            SET @n_TotalCarton = @n_TotalCarton + @n_CS
            SET @n_TotalLoose  = @n_TotalLoose + @n_PC 
            SET @n_TotalCases  = @n_TotalCases + @n_Cases
              
           NEXT_FETCH:                                                                              
           FETCH NEXT FROM CUR_PrePackQty INTO @c_storerkey, @c_sku, @n_QTY, @n_Pallet, @n_CaseCnt    

        END                  

    END  
END

GO