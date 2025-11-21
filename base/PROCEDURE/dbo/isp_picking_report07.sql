SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_picking_report07                                */
/* Creation Date: 2018-05-17                                             */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: WMS-4552 - KR - UA Replenishment Report                      */
/*                                                                       */
/* Called By: r_picking_report_07                                        */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver   Purposes                                   */
/*************************************************************************/

CREATE PROC [dbo].[isp_picking_report07]
         (  @c_wavekey           NVARCHAR(20) 
           ,@c_mode              NVARCHAR(5)    
         )
                 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_NoOfLine  INT
          ,@c_getUDF01  NVARCHAR(30)
          ,@c_PrvUDF01  NVARCHAR(30)
          ,@n_CtnUDF01  INT
          ,@n_ctnsct    INT
          ,@n_Ctnsmct   INT
          ,@n_rpqty     INT
   
   
   SET @n_CtnUDF01 = 1
   SET @c_PrvUDF01 = ''
   
   CREATE TABLE #TEMPPRPT07(
   RptTitle      NVARCHAR(150),
   loadkey       NVARCHAR(20) NULL,
   OHUDF09       NVARCHAR(10),
   SKU           NVARCHAR(20),
   Loc           NVARCHAR(20),
   scolor        NVARCHAR(20),
   ssize         NVARCHAR(20),
   PQTY          INT
   )
   
   
  -- SET @n_NoOfLine = 40
  
 DECLARE  @c_getwvkey          NVARCHAR(20),
          @c_loadkey           NVARCHAR(20),
          @n_TTLCTN            INT,
          @n_fcpqty            INT,
          @n_fcsqty            INT,
          @n_rplqty            INT,
          @c_Rpttitle          NVARCHAR(50),
          @n_qtyExp            INT,
          @c_SQLInsert         NVARCHAR(4000),
          @c_ExecArguments     NVARCHAR(4000),
          @c_SQL               NVARCHAR(4000),        
          @c_SQLSELECT         NVARCHAR(4000),        
          @c_SQLJOIN           NVARCHAR(4000),
          @c_condition1        NVARCHAR(150),
          @c_SQLWhere         NVARCHAR(4000) 
   
   
   IF @c_mode NOT IN ('F','A','N')
   BEGIN
      GOTO QUIT_SP
   END
   
   SET @c_SQLInsert  = N' INSERT INTO #TEMPPRPT07 ' 
                   +' ( RptTitle, '
                   +'  loadkey, OHUDF09, SKU, Loc,scolor,ssize, PQTY ) '   
                   
   SET @c_SQLSELECT = N' SELECT @c_Rpttitle,ISNULL(OH.loadkey,''''),OH.UserDefine09,PD.LOC,PD.SKU,S.color,s.size,sum(pd.qty)'              
   
  IF @c_mode = 'N'
  BEGIN  
        SET @c_Rpttitle =  'Picking Slip_Normal'
                      
        SET @c_SQLJOIN = N'FROM ORDERS  OH WITH (NOLOCK) '
                         + ' LEFT JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.orderkey = OH.Orderkey '
                         + ' LEFT JOIN SKU S WITH (NOLOCK) ON PD.Storerkey = S.Storerkey AND PD.Sku = S.Sku '
                         + ' WHERE OH.userdefine09 =@c_wavekey'
                         + ' GROUP BY OH.loadkey,OH.UserDefine09,PD.LOC,PD.SKU,S.color,s.size '
                         + ' Order by OH.loadkey,OH.UserDefine09,PD.LOC,PD.SKU '
                         
  END
  ELSE IF  @c_mode = 'F'    
  BEGIN
     SET @c_Rpttitle =  'Picking Slip_Footwear'
   
   SET @c_SQLJOIN = N'FROM ORDERS  OH WITH (NOLOCK) '
               + ' LEFT JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.orderkey = OH.Orderkey '
               + ' LEFT JOIN SKU S WITH (NOLOCK) ON PD.Storerkey = S.Storerkey AND PD.Sku = S.Sku '
               + ' LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname =''UASKUDIV'' '
               + '   AND C.udf01 = ''FW'' '
               + ' WHERE OH.userdefine09 =@c_wavekey'
               + ' GROUP BY OH.loadkey,OH.UserDefine09,PD.LOC,PD.SKU,S.color,s.size '
               + ' Order by OH.loadkey,OH.UserDefine09,PD.LOC,PD.SKU '
  END   
  ELSE IF  @c_mode = 'A'    
  BEGIN
     SET @c_Rpttitle =  'Picking Slip_APP'
   
   SET @c_SQLJOIN = N'FROM ORDERS  OH WITH (NOLOCK) '
               + ' LEFT JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.orderkey = OH.Orderkey '
               + ' LEFT JOIN SKU S WITH (NOLOCK) ON PD.Storerkey = S.Storerkey AND PD.Sku = S.Sku '
               + ' LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname =''UASKUDIV'' '
               + '  AND C.udf01  in (''APP'',''ACC'') '
               + ' WHERE OH.userdefine09 =@c_wavekey'
               + ' GROUP BY OH.loadkey,OH.UserDefine09,PD.LOC,PD.SKU,S.color,s.size '
               + ' Order by OH.loadkey,OH.UserDefine09,PD.LOC,PD.SKU '
  END   
  
   SET @c_SQL = @c_SQLInsert + CHAR(13) + @c_SQLSELECT + CHAR(13) + @c_SQLJOIN + CHAR(13) + @c_condition1 
   
   
    SET @c_ExecArguments = N'    @c_mode          NVARCHAR(150),'
                             + ' @c_wavekey       NVARCHAR(20),'
                             + ' @c_Rpttitle      NVARCHAR(150)'
                       
     EXEC sp_executesql  @c_SQL  
                       , @c_ExecArguments  
                       , @c_Rpttitle  
                       , @c_wavekey 
                       , @c_Rpttitle
   
   SELECT  *
   FROM #TEMPPRPT07 AS t
   ORDER BY loadkey,LOC,Sku
   
    QUIT_SP:
    
END


GO