SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetNameLabel        	          					*/
/* Creation Date: 16/07/2010                                            */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: SFC name label SOS#180292                                   */
/*                                                                      */
/* Called By: r_dw_name_Label                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 29-Oct-2010  NJOW01   1.1  194374 - Print label for every qty        */ 
/************************************************************************/

CREATE PROC [dbo].[isp_GetNameLabel] (@c_loadkey NVARCHAR(10))
 AS
 BEGIN
    SET NOCOUNT ON 
    SET QUOTED_IDENTIFIER OFF 
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF
    
    DECLARE @Result TABLE(
            Storerkey NVARCHAR(15) NULL,
            Orderkey NVARCHAR(10) NULL,
            Facility NVARCHAR(5) NULL,
            Loadkey NVARCHAR(10) NULL,
            Style NVARCHAR(20) NULL,
            Color NVARCHAR(10) NULL,
            Size NVARCHAR(5) NULL,
            Qty int NULL,
            ODUserdefine01 NVARCHAR(18) NULL,
            Pokey NVARCHAR(10) NULL,
            BuyerPo NVARCHAR(20) NULL,
            Linetype NVARCHAR(1) NULL)

    DECLARE @c_Storerkey NVARCHAR(15),
            @c_Orderkey NVARCHAR(10),
            @c_Facility NVARCHAR(5),
            @c_Style NVARCHAR(20),
            @c_Color NVARCHAR(10),
            @c_Size NVARCHAR(5),
            @n_Qty Int,
            @c_ODUserdefine01 NVARCHAR(18),
            @c_Pokey NVARCHAR(10),
            @c_BuyerPo NVARCHAR(20),
            @n_cnt Int
         
    SELECT ORDERS.Storerkey,
           ORDERS.Orderkey,
           ORDERS.Facility, 
           LOADPLAN.Loadkey,
           SKU.Style,
           SKU.Color,
           SKU.Size,
           SUM(PICKDETAIL.Qty) AS Qty,
           ISNULL(ORDERDETAIL.Userdefine01,'') AS ODUserdefine01,
           ORDERS.Pokey,
           ORDERS.BuyerPO,
           SKU.Itemclass,
           LK3.Code
    INTO #TEMP_LBL           
    FROM LOADPLAN (NOLOCK) 
    JOIN LOADPLANDETAIL (NOLOCK) ON (LOADPLAN.Loadkey = LOADPLANDETAIL.Loadkey)
    JOIN ORDERS (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)
    JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
    JOIN FACILITY (NOLOCK) ON (ORDERS.Facility = FACILITY.Facility)
    JOIN SKU (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey 
                          AND ORDERDETAIL.Sku = SKU.Sku) 
    JOIN PICKDETAIL (NOLOCK) ON (ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey 
                                 AND ORDERDETAIL.Orderlinenumber = PICKDETAIL.Orderlinenumber)
    JOIN CODELKUP (NOLOCK) ON (SKU.itemclass = CODELKUP.Code AND CODELKUP.Listname = 'NameLBCLS')                              
    JOIN CODELKUP LK2 (NOLOCK) ON (ORDERS.Invoiceno = LK2.Code AND LK2.Listname = 'SFCLabel')
    LEFT JOIN CODELKUP LK3 (NOLOCK) ON (ORDERDETAIL.Userdefine01 = LK3.Code AND LK3.Listname = 'SFCLabel2')
    WHERE LOADPLAN.Loadkey = @c_loadkey
    GROUP BY ORDERS.Storerkey,                             
             ORDERS.Orderkey,                              
             ORDERS.Facility,                              
             LOADPLAN.Loadkey,                             
             SKU.Style,                                    
             SKU.Color,                                    
             SKU.Size,                                     
             ORDERDETAIL.Userdefine01,   
             ORDERS.Pokey,                                 
             ORDERS.BuyerPO,
             SKU.Itemclass,
             LK3.Code
     --HAVING SUM(PICKDETAIL.Qty) >= 6           
     
     SELECT Orderkey, SUM(Qty) AS Qty
     INTO #ORD_SUM
     FROM #TEMP_LBL
     WHERE ODUserdefine01 <> ''
     GROUP BY Orderkey
     
     DECLARE CUR_LBL CURSOR FAST_FORWARD READ_ONLY FOR
     SELECT #TEMP_LBL.Storerkey, 
            #TEMP_LBL.Orderkey, 
            #TEMP_LBL.Facility, 
--            #TEMP_LBL.Loadkey, 
            #TEMP_LBL.Style, 
            #TEMP_LBL.Color, 
            #TEMP_LBL.Size, 
            #TEMP_LBL.Qty,   
            #TEMP_LBL.ODUserdefine01, 
            #TEMP_LBL.Pokey, 
            #TEMP_LBL.BuyerPO 
     FROM #TEMP_LBL 
     JOIN #ORD_SUM ON (#TEMP_LBL.Orderkey = #ORD_SUM.Orderkey)
     WHERE #ORD_SUM.Qty >= 6
     AND #TEMP_LBL.Code IS NULL
 
     OPEN CUR_LBL
     
     FETCH NEXT FROM CUR_LBL INTO @c_Storerkey, @c_Orderkey,  @c_Facility, @c_Style,
                                  @c_Color, @c_Size, @n_Qty, @c_ODUserdefine01, @c_Pokey, @c_BuyerPo
     WHILE @@FETCH_STATUS <> -1
     BEGIN
           SET @n_cnt = @n_Qty
           WHILE @n_cnt > 0
           BEGIN
              INSERT INTO @Result (Storerkey, Orderkey,  Facility, Loadkey, Style,
                                   Color, Size, Qty, ODUserdefine01, Pokey, BuyerPo, Linetype)
                          VALUES (@c_Storerkey, @c_Orderkey,  @c_Facility, @c_Loadkey, @c_Style,
                                  @c_Color, @c_Size, @n_Qty, @c_ODUserdefine01, @c_Pokey, @c_BuyerPo, '2')
              SELECT @n_cnt = @n_cnt - 1
           END

           FETCH NEXT FROM CUR_LBL INTO @c_Storerkey, @c_Orderkey, @c_Facility, @c_Style,
                                        @c_Color, @c_Size, @n_Qty, @c_ODUserdefine01, @c_Pokey, @c_BuyerPo
     END -- While
     DEALLOCATE CUR_LBL

     /*INSERT INTO @Result
     SELECT #TEMP_LBL.Storerkey, 
            #TEMP_LBL.Orderkey, 
            #TEMP_LBL.Facility, 
            #TEMP_LBL.Loadkey, 
            #TEMP_LBL.Style, 
            #TEMP_LBL.Color, 
            #TEMP_LBL.Size, 
            #TEMP_LBL.Qty,   
            #TEMP_LBL.ODUserdefine01, 
            #TEMP_LBL.Pokey, 
            #TEMP_LBL.BuyerPO, 
            '2' 
      FROM #TEMP_LBL 
      JOIN #ORD_SUM ON (#TEMP_LBL.Orderkey = #ORD_SUM.Orderkey)
      WHERE #ORD_SUM.Qty >= 6
      AND #TEMP_LBL.Code IS NULL*/

     INSERT INTO @Result (Storerkey, Orderkey, Facility, Loadkey, Pokey, Linetype)
     SELECT #TEMP_LBL.Storerkey, 
            #TEMP_LBL.Orderkey, 
            #TEMP_LBL.Facility, 
            #TEMP_LBL.Loadkey, 
            #TEMP_LBL.Pokey, 
            '1' 
     FROM #TEMP_LBL
     JOIN #ORD_SUM ON (#TEMP_LBL.Orderkey = #ORD_SUM.Orderkey)
     WHERE #ORD_SUM.Qty >= 6
     AND #TEMP_LBL.Code IS NULL
     GROUP BY #TEMP_LBL.Storerkey, 
              #TEMP_LBL.Orderkey, 
              #TEMP_LBL.Facility, 
              #TEMP_LBL.Loadkey, 
              #TEMP_LBL.Pokey
		        
     SELECT R.* 
     FROM @Result R
     JOIN #ORD_SUM ON (R.Orderkey = #ORD_SUM.Orderkey)    
     ORDER BY R.Loadkey, 
              #ORD_SUM.Qty,                
              R.Pokey,
              R.Orderkey,
              R.LineType,
              R.Qty DESC 
 END        

GO