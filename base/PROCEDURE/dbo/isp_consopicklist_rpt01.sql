SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ConsoPickList_Rpt01                                 */
/* Creation Date: 29-JUN-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-5255 - [TW] KSW View report Consolidate Pick Slip From  */
/*        : LoadPlan (New)                                              */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_ConsoPickList_Rpt01]
            @c_Storerkey   NVARCHAR(15)
         ,  @c_Loadkey     NVARCHAR(10)
         ,  @c_SortBy1     NVARCHAR(5)
         ,  @c_SortBy2     NVARCHAR(5)
         
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt    INT
         , @n_Continue     INT 

         , @n_TotalLoadQty INT
         , @c_AddSortBy    NVARCHAR(60)
         , @c_SQL          NVARCHAR(MAX)
         , @c_SQLParm      NVARCHAR(MAX)

   SET @n_StartTCnt = @@TRANCOUNT


      CREATE TABLE #TMP_CONSOPL
         (  RowRef         INT      IDENTITY(1,1)  PRIMARY KEY
         ,  SortBy         INT
         ,  PageBreakBy    INT
         ,  Loadkey        NVARCHAR(10)   NULL  
         ,  NoOfOrderkey   INT   
         ,  Storerkey      NVARCHAR(15)   NULL  
         ,  Lottable01     NVARCHAR(18)   NULL  
         ,  StyleColor     NVARCHAR(35)   NULL  
         ,  Size           NVARCHAR(10)   NULL  
         ,  Sku            NVARCHAR(20)   NULL  
         ,  Loc            NVARCHAR(10)   NULL  
         ,  ID             NVARCHAR(18)   NULL  
         ,  Qty            INT            NULL 
         )  

   SET @c_SortBy1 = ISNULL(RTRIM(@c_SortBy1),'')
   SET @c_SortBy2 = ISNULL(RTRIM(@c_SortBy2),'')
   SET @c_AddSortBy = CASE @c_SortBy1 WHEN 'SKU' THEN ',RTRIM(SKU.' + @c_SortBy1 + ')'
                                      WHEN 'LOC' THEN ',PD.'  + @c_SortBy1
                                      ELSE ''
                                      END  
                    + CASE @c_SortBy2 WHEN 'SKU' THEN ',RTRIM(SKU.' + @c_SortBy2 + ')'
                                      WHEN 'LOC' THEN ',PD.'  + @c_SortBy2
                                      ELSE ''
                                      END 

   SET @c_SQL = N'SELECT  SortBy = ROW_NUMBER() OVER ( ORDER BY OH.Loadkey'
              +                                        ',ISNULL(RTRIM(OD.Lottable01),'''')'
              +                                        @c_AddSortBy
              +                                    ' )'
              + ', PageBreakBy = RANK() OVER (  ORDER BY OH.Loadkey'
              +                                    ',ISNULL(RTRIM(OD.Lottable01),'''')'
              +                                    ' )'
              + ', OH.Loadkey'
              + ', COUNT(DISTINCT OH.ORderkey)'
              + ', OH.Storerkey'
              + ', Lottable01 = ISNULL(RTRIM(OD.Lottable01),'''')'
              + ', StyleColor = ISNULL(RTRIM(SKU.Style),'''') + ''-'' + ISNULL(RTRIM(SKU.Color),'''')'
              + ', Size= ISNULL(RTRIM(Sku.Size),'''')'
              + ', Sku = RTRIM(SKU.Sku)'
              + ', PD.Loc'
              + ', PD.ID'
              + ', Qty = ISNULL(SUM(PD.Qty),0)'
              --+ ', @c_SortBy1 + '' '' + @c_SortBy2'
              --+ ', PrintDateTime = GETDATE()'
              + ' FROM ORDERS       OH WITH (NOLOCK)' 
              + ' JOIN ORDERDETAIL  OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)'
              + ' JOIN PICKDETAIL   PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)'
              +                                    ' AND(OD.OrderLineNumber = PD.OrderLineNumber)'
              + ' JOIN SKU             WITH (NOLOCK) ON (PD.Storerkey= SKU.Storerkey)'
              +                                    ' AND(PD.Sku = SKU.Sku)'
              + ' WHERE OH.Storerkey = @c_Storerkey'
              + ' AND   OH.Loadkey = @c_Loadkey'
              + ' GROUP BY OH.Loadkey'
              + ', OH.Storerkey'
              + ', ISNULL(RTRIM(OD.Lottable01),'''')'
              + ', ISNULL(RTRIM(SKU.Style),'''')'
              + ', ISNULL(RTRIM(SKU.Color),'''')'
              + ', ISNULL(RTRIM(SKU.Size),'''')'
              + ', RTRIM(SKU.Sku)'
              + ', PD.Loc'
              + ', PD.ID'

   SET @c_SQLParm = N'@c_Storerkey  NVARCHAR(15)'
                  + ',@c_Loadkey    NVARCHAR(10)'
                  --+ ',@c_SortBy1    NVARCHAR(20)'
                  --+ ',@c_SortBy2    NVARCHAR(20)'
   INSERT INTO #TMP_CONSOPL
      (  SortBy         
      ,  PageBreakBy     
      ,  Loadkey          
      ,  NoOfOrderkey       
      ,  Storerkey      
      ,  Lottable01        
      ,  StyleColor       
      ,  Size            
      ,  Sku              
      ,  Loc              
      ,  ID               
      ,  Qty               
      )  
   EXEC sp_ExecuteSQL  @c_SQL
                     , @c_SQLParm
                     , @c_Storerkey
                     , @c_LoadKey
                    -- , @c_SortBy1
                    -- , @c_SortBy2


   SET @n_TotalLoadQty = 0      
   SELECT @n_TotalLoadQty = ISNULL(SUM(Qty),0)
   FROM #TMP_CONSOPL

   SELECT SortBy         
      ,  PageBreakBy     
      ,  Loadkey          
      ,  @n_TotalLoadQty
      ,  NoOfOrderkey       
      ,  Storerkey      
      ,  Lottable01        
      ,  StyleColor       
      ,  Size            
      ,  Sku              
      ,  Loc              
      ,  ID               
      ,  Qty 
      ,  @c_SortBy1 + ' ' + @c_SortBy2
      ,  PrintDateTime = GETDATE()
   FROM #TMP_CONSOPL
   ORDER BY RowRef

   DROP TABLE #TMP_CONSOPL
END -- procedure

GO