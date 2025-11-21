SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/    
/* Stored Procedure: isp_Delivery_Note56_RDT                             */    
/* Creation Date: 2022-01-05                                             */    
/* Copyright: IDS                                                        */    
/* Written by:                                                           */    
/*                                                                       */    
/* Purpose: WMS-18625 - COS AU Delivery Note                             */    
/*                                                                       */    
/* Called By: r_dw_delivery_Note56_rdt                                   */      
/*                                                                       */    
/* PVCS Version: 1.1                                                     */    
/*                                                                       */    
/* Version: 5.4                                                          */    
/*                                                                       */    
/* Data Modifications:                                                   */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date         Author   Ver   Purposes                                  */    
/* 05-JAN-2022  CSCHONG  1.1   Devops Scripts Combine                    */    
/*************************************************************************/    
    
CREATE PROC [dbo].[isp_Delivery_Note56_RDT]     
         (  @c_BUYERPO      NVARCHAR(20)= ''    
         ,  @c_Orderkey     NVARCHAR(10)= '' 
         ,  @c_cartonno     NVARCHAR(10) = ''
         ,  @c_labelno      NVARCHAR(20) = ''
       --  ,  @c_Type         NVARCHAR(1) = ''    
         ,  @c_DWCategory   NVARCHAR(3) = 'H'    
         ,  @n_RecGroup     INT         = 0    
         )               
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @n_NoOfLine     INT    
         , @n_TotDetail    INT    
         , @n_LineNeed     INT    
         , @n_SerialNo     INT    
         , @b_debug        INT    
         , @n_CntLine      INT    
         , @n_RecNo        INT    
         , @n_NoOfPage     INT    
         , @c_GetOrderkey  NVARCHAR(10)     
         , @c_getRecGrp    INT    
         , @n_CntGrp       INT    
         , @n_totalPage    INT    
         , @n_CurrGrp      INT    
         , @n_cntPNote     INT    
         , @n_seqno        INT    
         , @n_CntTTLLine   INT
         , @c_multicarton  NVARCHAR(5) = 'N'     
             
   DECLARE     @c_A0100         NVARCHAR(800) = ''   
            ,  @c_A0101         NVARCHAR(800) = ''     
            ,  @c_A0102         NVARCHAR(800) = ''     
            ,  @c_A0103         NVARCHAR(800) = ''                
            ,  @c_A0104         NVARCHAR(800) = ''      
            ,  @c_A0105         NVARCHAR(800) = ''     
            ,  @c_A0106         NVARCHAR(800) = ''     
            ,  @c_A0107         NVARCHAR(800) = ''     
            ,  @c_A0108         NVARCHAR(800) = ''     
            ,  @c_A0200         NVARCHAR(800) = ''     
            ,  @c_A0201         NVARCHAR(800) = ''     
            ,  @c_A0202         NVARCHAR(800) = ''     
            ,  @c_A0300         NVARCHAR(800) = ''     
            ,  @c_A0301         NVARCHAR(800) = ''     
            ,  @c_A0302         NVARCHAR(800) = ''      
            ,  @c_A0303         NVARCHAR(800) = ''      
            ,  @c_A0304         NVARCHAR(800) = ''      
            ,  @c_A0305         NVARCHAR(800) = ''      
            ,  @c_B0100         NVARCHAR(800) = ''     
            ,  @c_B0101         NVARCHAR(800) = ''     
            ,  @c_B0102         NVARCHAR(800) = ''     
            ,  @c_B0103         NVARCHAR(800) = ''     
            ,  @c_B0110         NVARCHAR(800) = ''     
            ,  @c_B0111         NVARCHAR(800) = ''          
            ,  @c_B0112         NVARCHAR(800) = ''           
            ,  @c_B0113         NVARCHAR(800) = ''          
            ,  @c_C0100         NVARCHAR(800) = ''          
            ,  @c_C0101         NVARCHAR(800) = ''          
            ,  @c_C0102         NVARCHAR(800) = ''         
            ,  @c_C0103         NVARCHAR(800) = ''          
            ,  @c_C0104         NVARCHAR(800) = ''          
            ,  @c_C0105         NVARCHAR(800) = ''          
            ,  @c_C0106         NVARCHAR(800) = '' 
            ,  @c_C0107         NVARCHAR(800) = ''          
            ,  @c_C0108         NVARCHAR(800) = ''          
            ,  @c_C0200         NVARCHAR(800) = ''          
            ,  @c_C0201         NVARCHAR(800) = ''                  
            ,  @c_C0202         NVARCHAR(800) = ''          
            ,  @c_C0203         NVARCHAR(800) = ''          
            ,  @c_C0204         NVARCHAR(800) = ''  
            ,  @c_C0205         NVARCHAR(800) = ''          
            ,  @c_C0206         NVARCHAR(800) = ''                  
            ,  @c_C0207         NVARCHAR(800) = ''          
            ,  @c_C0208         NVARCHAR(800) = ''          
            ,  @c_C0210         NVARCHAR(800) = ''     
            ,  @c_C0211         NVARCHAR(800) = ''  
            ,  @c_C0212         NVARCHAR(800) = ''  
            ,  @c_C0213         NVARCHAR(800) = ''    
            ,  @c_storerkey     NVARCHAR(20)    
            ,  @c_country       NVARCHAR(10)                      
            ,  @c_ExecArguments    NVARCHAR(4000)               
            ,  @c_sql              NVARCHAR(MAX)              
            ,  @c_insertsql        NVARCHAR(MAX)              
            ,  @c_chkCancelitem    NVARCHAR(5)                
            ,  @c_OHORDkey         NVARCHAR(10)
            ,  @n_ctnordline       INT  = 0
            ,  @n_ctnpdline        INT = 0
            ,  @c_splitctn         NVARCHAR(1) = 'N'  
            ,  @c_getordkey        NVARCHAR(20) = ''          
    
   DECLARE @c_ExecStatements NVARCHAR(MAX)    
   DECLARE @c_ExecStatements2 NVARCHAR(MAX)    
   DECLARE @c_ExecWhere NVARCHAR(4000),@c_ExecHaving NVARCHAR(4000),@c_ExecOrderBy NVARCHAR(4000)        
       
   SET @c_ExecStatements = ''    
   SET @c_ExecStatements2 = ''    
   SET @c_ExecWhere = ''    
   SET @n_NoOfLine = 10    
   SET @n_TotDetail= 0    
   SET @n_LineNeed = 0    
   SET @n_SerialNo = 0    
   SET @b_debug    = 0    
   SET @n_CntLine = 1    
   SET @n_RecNo = 1    
   SET @n_NoOfPage = 1    
   SET @c_GetOrderkey = ''    
   SET @n_CntGrp = 1    
   SET @n_totalPage = 1    
   SET @n_CurrGrp = 2     
   SET @n_cntPNote = 1    
   SET @n_seqno = 0    
   SET @n_CntTTLLine = 1    
       
   SET @c_ExecHaving = ''                      
   SET @c_ExecOrderBy = ''                     
   SET @c_country     = ''                        
       
   SELECT @c_country = nsqlvalue    
   FROM NSQLCONFIG AS n WITH (NOLOCK)    
   WHERE n.ConfigKey='COUNTRY'    

   SELECT    @c_A0100 = ISNULL(MAX(CASE WHEN CL.Code = 'A0100'  THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')
            ,@c_A0101 = ISNULL(MAX(CASE WHEN CL.Code = 'A0101'  THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')
            ,@c_A0102 = ISNULL(MAX(CASE WHEN CL.Code = 'A0102'  THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')
            ,@c_A0103 = ISNULL(MAX(CASE WHEN CL.Code = 'A0103'  THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')
            ,@c_A0104 = ISNULL(MAX(CASE WHEN CL.Code = 'A0104'  THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')
            ,@c_A0105 = ISNULL(MAX(CASE WHEN CL.Code = 'A0105'  THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')
            ,@c_A0106 = ISNULL(MAX(CASE WHEN CL.Code = 'A0106'  THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')
            ,@c_A0107 = ISNULL(MAX(CASE WHEN CL.Code = 'A0107'  THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')
            ,@c_A0108 = ISNULL(MAX(CASE WHEN CL.Code = 'A0108'  THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')
            ,@c_A0200 = ISNULL(MAX(CASE WHEN CL.Code = 'A0200' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')
            ,@c_A0201 = ISNULL(MAX(CASE WHEN CL.Code = 'A0201' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')
            ,@c_A0202 = ISNULL(MAX(CASE WHEN CL.Code = 'A0202' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')
            ,@c_A0300 = ISNULL(MAX(CASE WHEN CL.Code = 'A0300' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')
            ,@c_A0301 = ISNULL(MAX(CASE WHEN CL.Code = 'A0301' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')
            ,@c_A0302 = ISNULL(MAX(CASE WHEN CL.Code = 'A0302' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')
            ,@c_A0303 = ISNULL(MAX(CASE WHEN CL.Code = 'A0303' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')
            ,@c_A0304 = ISNULL(MAX(CASE WHEN CL.Code = 'A0304' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')
            ,@c_A0305 = ISNULL(MAX(CASE WHEN CL.Code = 'A0305' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')    
            ,@c_B0100 = ISNULL(MAX(CASE WHEN CL.Code = 'B0100' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')    
            ,@c_B0101 = ISNULL(MAX(CASE WHEN CL.Code = 'B0101' THEN ISNULL(RTRIM(CL.description),'') + ISNULL(RTRIM(CL.long),'') ELSE '' END),'')    
            ,@c_B0102 = ISNULL(MAX(CASE WHEN CL.Code = 'B0102' THEN ISNULL(RTRIM(CL.description),'') + ISNULL(RTRIM(CL.long),'') ELSE '' END),'')    
            ,@c_B0103 = ISNULL(MAX(CASE WHEN CL.Code = 'B0103' THEN ISNULL(RTRIM(CL.description),'') + ISNULL(RTRIM(CL.long),'') ELSE '' END),'')    
            ,@c_B0110 = ISNULL(MAX(CASE WHEN CL.Code = 'B0110' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')    
            ,@c_B0111 = ISNULL(MAX(CASE WHEN CL.Code = 'B0111' THEN ISNULL(RTRIM(CL.description),'') + ISNULL(RTRIM(CL.long),'') ELSE '' END),'')    
            ,@c_B0112 = ISNULL(MAX(CASE WHEN CL.Code = 'B0112' THEN ISNULL(RTRIM(CL.description),'') + ISNULL(RTRIM(CL.long),'') ELSE '' END),'')  
            ,@c_B0113 = ISNULL(MAX(CASE WHEN CL.Code = 'B0113' THEN ISNULL(RTRIM(CL.description),'') + ISNULL(RTRIM(CL.long),'') ELSE '' END),'')  
            ,@c_C0100 = ISNULL(MAX(CASE WHEN CL.Code = 'C0100' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')  
            ,@c_C0101 = ISNULL(MAX(CASE WHEN CL.Code = 'C0101' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')  
            ,@c_C0102 = ISNULL(MAX(CASE WHEN CL.Code = 'C0102' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')  
            ,@c_C0103 = ISNULL(MAX(CASE WHEN CL.Code = 'C0103' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')  
            ,@c_C0104 = ISNULL(MAX(CASE WHEN CL.Code = 'C0104' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')  
            ,@c_C0105 = ISNULL(MAX(CASE WHEN CL.Code = 'C0105' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')  
            ,@c_C0106 = ISNULL(MAX(CASE WHEN CL.Code = 'C0106' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')  
            ,@c_C0107 = ISNULL(MAX(CASE WHEN CL.Code = 'C0107' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')  
            ,@c_C0108 = ISNULL(MAX(CASE WHEN CL.Code = 'C0108' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')  
            ,@c_C0200 = ISNULL(MAX(CASE WHEN CL.Code = 'C0200' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')  
            ,@c_C0201 = ISNULL(MAX(CASE WHEN CL.Code = 'C0201' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'') 
            ,@c_C0202 = ISNULL(MAX(CASE WHEN CL.Code = 'C0202' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'') 
            ,@c_C0203 = ISNULL(MAX(CASE WHEN CL.Code = 'C0203' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'') 
            ,@c_C0204 = ISNULL(MAX(CASE WHEN CL.Code = 'C0204' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'') 
            ,@c_C0205 = ISNULL(MAX(CASE WHEN CL.Code = 'C0205' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'') 
            ,@c_C0206 = ISNULL(MAX(CASE WHEN CL.Code = 'C0206' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'') 
            ,@c_C0207 = ISNULL(MAX(CASE WHEN CL.Code = 'C0207' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'') 
            ,@c_C0208 = ISNULL(MAX(CASE WHEN CL.Code = 'C0208' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')    
            ,@c_C0210 = ISNULL(MAX(CASE WHEN CL.Code = 'C0210' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')     
            ,@c_C0211 = ISNULL(MAX(CASE WHEN CL.Code = 'C0211' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')  
            ,@c_C0212 = ISNULL(MAX(CASE WHEN CL.Code = 'C0212' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')  
            ,@c_C0213 = ISNULL(MAX(CASE WHEN CL.Code = 'C0213' THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')                      
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = 'COSDN'


   IF OBJECT_ID('tempdb..#TMP_ORDDN56RDTDETSA2') IS NOT NULL 
      DROP TABLE #TMP_ORDDN56RDTDETSA2

 IF OBJECT_ID('tempdb..#TMP_ORDDN56RDTDETSA2') IS NOT NULL 
      DROP TABLE #TMP_ORDDN56RDTDETSC2

      CREATE TABLE #TMP_ORDDN56RDTDETSA2    
            (  SeqNo          INT NOT NULL IDENTITY (1,1) PRIMARY KEY     
            ,  Orderkey       NVARCHAR(10) DEFAULT ('')    
            ,  OrdlineNo      NVARCHAR(10) DEFAULT ('')    
            ,  ORDSKU         NVARCHAR(20) DEFAULT ('')       
            ,  TotalPickQty   INT          DEFAULT (0)    
            ,  TotalOrdQty    INT          DEFAULT (0)  
            ,  Sdescr         NVARCHAR(250) DEFAULT ('')  
            ,  SSize          NVARCHAR(10)  DEFAULT ('')  
            ,  Storerkey      NVARCHAR(20) DEFAULT ('')  
            ,  Labelno        NVARCHAR(20) DEFAULT ('')    
            ,  Cartonno       INT
            ,  RecGrp         INT    
            )    


      CREATE TABLE #TMP_ORDDN56RDTDETSC2    
            (  SeqNo          INT NOT NULL IDENTITY (1,1) PRIMARY KEY     
            ,  Orderkey       NVARCHAR(10) DEFAULT ('')    
            ,  OrdlineNo      NVARCHAR(10) DEFAULT ('')    
            ,  ORDSKU         NVARCHAR(20) DEFAULT ('')       
            ,  TotalPickQty   INT          DEFAULT (0)    
            ,  TotalOrdQty    INT          DEFAULT (0)  
            ,  Sdescr         NVARCHAR(250) DEFAULT ('')  
            ,  SSize          NVARCHAR(10)  DEFAULT ('')  
            ,  Storerkey      NVARCHAR(20) DEFAULT ('')  
            ,  Labelno        NVARCHAR(20) DEFAULT ('')    
            ,  Cartonno       INT
            ,  RecGrp         INT    
            ,  RowNo          INT
            )
    
      SET @c_ExecWhere = ''    
      IF ISNULL(RTRIM(@c_BUYERPO), '') <> ''    
      BEGIN    
         SET @c_ExecWhere = @c_ExecWhere + ' OH.buyerpo =  @c_BUYERPO '    
      END    
    
      IF ISNULL(RTRIM(@c_Orderkey), '') <> ''    
      BEGIN    
         IF ISNULL(LTRIM(RTRIM (@c_ExecWhere) ), '') <> ''    
         BEGIN    
            SET @c_ExecWhere = @c_ExecWhere + ' AND '    
         END    
         SET @c_ExecWhere = @c_ExecWhere + ' OH.Orderkey = @c_Orderkey '    
         SET @c_ExecOrderBy = ' PD.Orderkey'    
      END  

     IF ISNULL(RTRIM(@c_cartonno), '') <> ''    
      BEGIN    
         IF ISNULL(LTRIM(RTRIM (@c_ExecWhere) ), '') <> ''    
         BEGIN    
            SET @c_ExecWhere = @c_ExecWhere + ' AND '    
         END    
         SET @c_ExecWhere = @c_ExecWhere + ' PAD.Cartonno = CAST(@c_cartonno AS INT) '    
         --SET @c_ExecOrderBy = ' PD.Orderkey'    
      END   

      IF ISNULL(RTRIM(@c_labelno), '') <> ''    
      BEGIN    
         IF ISNULL(LTRIM(RTRIM (@c_ExecWhere) ), '') <> ''    
         BEGIN    
            SET @c_ExecWhere = @c_ExecWhere + ' AND '    
         END    
         SET @c_ExecWhere = @c_ExecWhere + ' PAD.labelno = @c_labelno'    
         --SET @c_ExecOrderBy = ' PD.Orderkey'    
      END      

      SET @c_ExecOrderBy = '  OH.Orderkey,MIN(OD.OrderlineNumber),ISNULL(PAD.Cartonno,0),OD.sku, ISNULL(PAD.Labelno,'''')  '
    
      SET @c_ExecStatements = 'SELECT OH.Orderkey,MIN(OD.OrderlineNumber),OD.sku ' +    
                              ',ISNULL(PAD.Qty,0) ' +    
                              ',SUM(OD.OriginalQty) ' +  
                              ',S.descr, S.size,OH.Storerkey, ISNULL(PAD.Labelno,''''),ISNULL(PAD.Cartonno,0)'  +
                              ',(Row_Number() OVER (PARTITION BY OH.Orderkey ORDER BY OH.Orderkey,MIN(OD.OrderlineNumber),ISNULL(PAD.Cartonno,0),OD.sku Asc)-1)/' + CAST(@n_NoOfLine AS NVARCHAR(5) ) +' ' +    
                              'FROM ORDERS OH WITH (NOLOCK)  ' +    
                               ' JOIN ORDERDETAIL OD WITH (NOLOCK)  ON OD.Orderkey = OH.Orderkey   ' +
                            -- 'LEFT JOIN PICKDETAIL PD  WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey AND OD.storerkey = PD.storerkey AND OD.sku=PD.sku) ' +    
                              ' LEFT JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.OrderKey = OH.OrderKey ' +
                             -- 'LEFT JOIN PACKDETAIL PAD WITH (NOLOCK) ON PAD.Labelno = PD.Caseid  '+
                              ' LEFT JOIN PACKDETAIL PAD WITH (NOLOCK) ON PAD.PickSlipNo = PH.PickSlipNo AND PAD.sku = OD.sku AND PAD.StorerKey = OD.StorerKey ' +
                              'JOIN SKU S   WITH (NOLOCK) ON (S.Storerkey = OD.Storerkey AND S.sku = OD.sku) ' +    
                              'WHERE ' + @c_ExecWhere + CHAR(13) +    
                              'GROUP BY OH.Orderkey,OD.sku,S.descr,S.size,OH.Storerkey,ISNULL(PAD.Cartonno,0),ISNULL(PAD.Labelno,''''),ISNULL(PAD.Qty,0)  '+ CHAR(13) +   --+ @c_ExecHaving + CHAR(13) +    
                              'ORDER BY ' + @c_ExecOrderBy    
            
     SET @c_insertsql = ' INSERT INTO #TMP_ORDDN56RDTDETSA2 ' +    
        ' (  Orderkey' +  
        ' ,  OrdLineNo ' +  
        ' ,  ORDSKU' +    
        ' ,  TotalPickQty' +    
        ' ,  TotalOrdQty ' +  
        ' ,  Sdescr '      +
        ' ,  Ssize '       +
        ' ,  Storerkey '   + 
        ' ,  LabelNo '     +
        ' ,  Cartonno '    +
        ' ,  RecGrp ) '    
            
      SET @c_sql = @c_insertsql + CHAR(13) + @c_ExecStatements     
          
      SET @c_ExecArguments = N'   @c_BUYERPO          NVARCHAR(20)'        
                            +   ',@c_Orderkey         NVARCHAR(20)'   
                            +   ',@c_cartonno         NVARCHAR(10)'
                            +   ',@c_labelno          NVARCHAR(20)'  
                         --   +   ',@c_Type             NVARCHAR(20)'     
                           
                             
   EXEC sp_ExecuteSql     @c_SQL         
                        , @c_ExecArguments        
                        , @c_BUYERPO        
                        , @c_Orderkey    
                        , @c_cartonno
                        , @c_labelno 
  

     -- SELECT @c_sql '@c_sql'

      --SELECT @c_DWCategory '@c_DWCategory'

  --  SELECT * FROM #TMP_ORDDN56RDTDETSA2
SELECT @n_ctnordline = COUNT(DISTINCT OrdlineNo)
FROM #TMP_ORDDN56RDTDETSA2

SELECT TOP 1 @c_GetOrderkey = Orderkey
FROM #TMP_ORDDN56RDTDETSA2

SELECT @n_ctnpdline = COUNT(DISTINCT pd.OrderLineNumber)
FROM pickdetail PD WITH (NOLOCK)
WHERE pd.OrderKey = @c_GetOrderkey


IF @n_ctnordline > @n_ctnpdline
BEGIN
   SET @c_splitctn = 'Y'
END

   IF @c_DWCategory = 'SA2'    
   BEGIN    
      GOTO  DETAIL_SA2    
   END  
   ELSE IF @c_DWCategory = 'SC2'    
   BEGIN    
      INSERT INTO #TMP_ORDDN56RDTDETSC2
      (
          Orderkey,
          OrdlineNo,
          ORDSKU,
          TotalPickQty,
          TotalOrdQty,
          Sdescr,
          SSize,
          Storerkey,
          Labelno,
          Cartonno,
          RecGrp,
          RowNo
      )
      SELECT Orderkey,
          OrdlineNo,
          ORDSKU,
          TotalPickQty,
          TotalOrdQty,
          Sdescr,
          SSize,
          Storerkey,
          Labelno,
          Cartonno,
          RecGrp,
          RowNo = ROW_NUMBER() OVER (PARTITION BY Orderkey ORDER BY Orderkey,OrdlineNo)
      FROM #TMP_ORDDN56RDTDETSA2
      WHERE Cartonno >= 1 AND OrdlineNo <> ''

      GOTO  DETAIL_SC2    
   END 
    
   HEADER:    
        

  IF OBJECT_ID('tempdb..#TMP_ORDHDN56RDT') IS NOT NULL 
      DROP TABLE #TMP_ORDHDN56RDT
    
      CREATE TABLE #TMP_ORDHDN56RDT    
            (  SeqNo         INT NOT NULL IDENTITY (1,1) PRIMARY KEY    
            ,  Orderkey      NVARCHAR(10)              
            ,  A0100         NVARCHAR(800)       
            ,  A0107         NVARCHAR(800)    
            ,  A0108         NVARCHAR(800)    
            ,  A0200         NVARCHAR(800)    
            ,  A0201         NVARCHAR(800)    
            ,  A0202         NVARCHAR(800)    
            ,  A0300         NVARCHAR(800)    
            ,  A0301         NVARCHAR(800)    
            ,  A0302         NVARCHAR(800)     
            ,  A0303         NVARCHAR(800)     
            ,  A0304         NVARCHAR(800)     
            ,  A0305         NVARCHAR(800)     
            ,  B0100         NVARCHAR(800)    
            ,  B0101         NVARCHAR(800)    
            ,  B0102         NVARCHAR(800)    
            ,  B0103         NVARCHAR(800)    
            ,  B0110         NVARCHAR(800)    
            ,  B0111         NVARCHAR(1200)         
            ,  B0112         NVARCHAR(800)          
            ,  B0113         NVARCHAR(800)         
            ,  C0100         NVARCHAR(800)   
            ,  C0107         NVARCHAR(800)         
            ,  C0108         NVARCHAR(800)         
            ,  C0200         NVARCHAR(800)         
            ,  C0201         NVARCHAR(800)                 
            ,  C0202         NVARCHAR(800)         
            ,  C0203         NVARCHAR(800)         
            ,  C0204         NVARCHAR(800) 
            ,  C0205         NVARCHAR(800)         
            ,  C0206         NVARCHAR(800)                 
            ,  C0207         NVARCHAR(800)         
            ,  C0208         NVARCHAR(800)         
            ,  C0210         NVARCHAR(800)                             
            ,  RecGroup      INT    
            ,  ExtOrderkey   NVARCHAR(50)     
            ,  OrdDate       NVARCHAR(10)  
            ,  C0211         NVARCHAR(800) 
            ,  C0212         NVARCHAR(800) 
            ,  C0213         NVARCHAR(800)               
            ,  STCompany     NVARCHAR(45)
            ,  STBCompany    NVARCHAR(45)
            ,  STVAT         NVARCHAR(18)
            ,  STEmail1      NVARCHAR(60)
            ,  STPhone1      NVARCHAR(18)
            ,  SplitCtn      NVARCHAR(1)
            ) 
    
--SELECT * FROM #TMP_ORDHDN56RDT    
--ORDER BY SeqNo    
            
INSERT INTO #TMP_ORDHDN56RDT              
           (                            
               Orderkey                                  
            ,  A0100           
            ,  A0107      
            ,  A0108      
            ,  A0200      
            ,  A0201      
            ,  A0202      
            ,  A0300      
            ,  A0301      
            ,  A0302      
            ,  A0303      
            ,  A0304      
            ,  A0305      
            ,  B0100      
            ,  B0101      
            ,  B0102      
            ,  B0103      
            ,  B0110      
            ,  B0111      
            ,  B0112      
            ,  B0113      
            ,  C0100           
            ,  RecGroup   
            ,  ExtOrderkey     
            ,  OrdDate     
            ,  C0107      
            ,  C0108      
            ,  C0200      
            ,  C0201      
            ,  C0202      
            ,  C0203      
            ,  C0204      
            ,  C0205      
            ,  C0206      
            ,  C0207      
            ,  C0208      
            ,  C0210      
            ,  C0211      
            ,  C0212      
            ,  C0213      
            ,  STCompany
            ,  STBCompany
            ,  STVAT
            ,  STEmail1
            ,  STPhone1   
            ,  SplitCtn                           
           ) 

        SELECT DISTINCT  tmp.Orderkey      
                     ,  A0100  =  @c_A0100    
                     ,  A0107  =  @c_A0107  
                     ,  A0108  =  @c_A0108  
                     ,  A0200  =  @c_A0200  
                     ,  A0201  =  @c_A0201  
                     ,  A0202  =  @c_A0202  
                     ,  A0300  =  @c_A0300  
                     ,  A0301  =  @c_A0301  
                     ,  A0302  =  @c_A0302  
                     ,  A0303  =  @c_A0303  
                     ,  A0304  =  @c_A0304  
                     ,  A0305  =  @c_A0305  
                     ,  B0100  =  @c_B0100  
                     ,  B0101  =  @c_B0101  
                     ,  B0102  =  @c_B0102  
                     ,  B0103  =  @c_B0103  
                     ,  B0110  =  @c_B0110  
                     ,  B0111  =  @c_B0111  
                     ,  B0112  =  @c_B0112  
                     ,  B0113  =  @c_B0113  
                     ,  C0100  =  @c_C0100   
                     ,  TMP.RecGrp            
                     ,  ISNULL(RTRIM(OH.ExternOrderKey),'')               
                     ,  CONVERT(NVARCHAR(10),OH.OrderDate,103)              
                     ,  C0107  =  @c_C0107  
                     ,  C0108  =  @c_C0108  
                     ,  C0200  =  @c_C0200  
                     ,  C0201  =  @c_C0201  
                     ,  C0202  =  @c_C0202  
                     ,  C0203  =  @c_C0203  
                     ,  C0204  =  @c_C0204  
                     ,  C0205  =  @c_C0205  
                     ,  C0206  =  @c_C0206  
                     ,  C0207  =  @c_C0207  
                     ,  C0208  =  @c_C0208  
                     ,  C0210  =  @c_C0210  
                     ,  C0211  =  @c_C0211  
                     ,  C0212  =  @c_C0212  
                     ,  C0213  =  @c_C0213 
                     ,  ISNULL(ST.Company,'')
                     ,  ISNULL(ST.B_Company,'')
                     ,  ISNULL(ST.VAT,'')      
                     ,  ISNULL(ST.Email1,'')
                     ,  ISNULL(ST.Phone1,'')
                     , Splitctn = @c_splitctn
            FROM #TMP_ORDDN56RDTDETSA2 TMP      
            JOIN ORDERS OH WITH (NOLOCK) ON (TMP.Orderkey = OH.Orderkey)       
            JOIN STORER ST WITH (NOLOCK) ON OH.Storerkey = ST.Storerkey       
            JOIN ORDERDETAIL OD WITH (NOLOCK) ON OH.Orderkey = OD.Orderkey              
             GROUP BY tmp.Orderkey      
            ,OH.Storerkey          
            ,  TMP.RecGrp    
            ,ISNULL(RTRIM(OH.ExternOrderKey),'')       
            ,CONVERT(NVARCHAR(10),OH.OrderDate,103)       
            ,ISNULL(ST.Company,'')
            ,ISNULL(ST.B_Company,'')
            ,ISNULL(ST.VAT,'')      
            ,ISNULL(ST.Email1,'')
            ,ISNULL(ST.Phone1,'')      
             ORDER BY TMP.Orderkey    
            --' ORDER BY ISNULL(PD.notes,''), OH.Orderkey    
                         
    
IF @b_debug = 1    
BEGIN    
   INSERT INTO TRACEINFO (TraceName, timeIn, Step1, Step2, step3, step4, step5)    
   VALUES ('isp_Delivery_Note56_RDT_H', getdate(), @c_DWCategory, @c_BUYERPO, @c_orderkey, @c_cartonno, suser_name())    
END    
    
      SELECT * FROM #TMP_ORDHDN56RDT    
      --ORDER BY pnotes,orderkey,OrdGrp     
      ORDER BY seqno    
       
      GOTO QUIT_SP    
    
 DETAIL_SA2:    

       SELECT  SeqNo
            ,  Orderkey     
            ,  OrdlineNo      
            ,  ORDSKU           
            ,  TotalPickQty  
            ,  TotalOrdQty   
            ,  RecGrp  
            ,  Sdescr         
            ,  SSize          
            ,  Storerkey      
            ,  Labelno       
            ,  Cartonno             
            ,  A0101 = @c_A0101
            ,  A0102 = @c_A0102
            ,  A0103 = @c_A0103
            ,  A0104 = @c_A0104
            ,  A0105 = @c_A0105
            ,  A0106 = @c_A0106  
      FROM #TMP_ORDDN56RDTDETSA2
      WHERE Orderkey = @c_Orderkey AND RecGrp = @n_RecGroup
      ORDER BY seqno
         
  GOTO QUIT_SP    

     DETAIL_SC2:    

       SELECT  SeqNo
            ,  Orderkey     
            ,  OrdlineNo      
            ,  ORDSKU           
            ,  TotalPickQty  
            ,  TotalOrdQty  
            ,  RecGrp 
            ,  Sdescr         
            ,  SSize          
            ,  Storerkey      
            ,  Labelno       
            ,  Cartonno               
            ,  C0101 = @c_C0101
            ,  C0102 = @c_C0102
            ,  C0103 = @c_C0103
            ,  C0104 = @c_C0104
            ,  C0105 = @c_C0105
            ,  C0106 = @c_C0106  
            ,  RowNo = ROW_NUMBER() OVER (ORDER BY SeqNo)
      FROM #TMP_ORDDN56RDTDETSC2
      WHERE Orderkey = @c_Orderkey AND RecGrp = @n_RecGroup
     -- AND Cartonno >= 1 AND OrdlineNo <> ''
         
  GOTO QUIT_SP
    
  --DROP TABLE #TMP_ORD    
  --DROP TABLE #TMP_HDRDN56RDT 
  --DROP TABLE #TMP_ORDHDN56RDT    
    
   QUIT_SP:    


      IF OBJECT_ID('tempdb..#TMP_ORDHDN56RDT') IS NOT NULL 
      DROP TABLE #TMP_ORDHDN56RDT

      IF OBJECT_ID('tempdb..#TMP_ORDDN56RDTDETSA2') IS NOT NULL 
      DROP TABLE #TMP_ORDDN56RDTDETSA2

     IF OBJECT_ID('tempdb..#TMP_ORDDN56RDTDETSA2') IS NOT NULL 
      DROP TABLE #TMP_ORDDN56RDTDETSC2

END     


GO