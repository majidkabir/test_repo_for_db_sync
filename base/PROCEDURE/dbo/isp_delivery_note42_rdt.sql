SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_Delivery_Note42_RDT                             */
/* Creation Date: 2020-02-18                                             */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: WMS-11776 - JP_HM_Datawindow_DeliveryNote_CR                 */
/*                                                                       */
/* Called By: r_dw_delivery_note42_rdt                                   */
/*            copy from r_dw_delivery_note19_rdt                         */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver   Purposes                                  */
/* 03-MAR-21    CSCHONG  1.1   WMS-16418 add new field (CS01)            */
/*************************************************************************/

CREATE PROC [dbo].[isp_Delivery_Note42_RDT] 
         (  @c_Storerkey      NVARCHAR(10)
         ,  @c_LoadkeyStart   NVARCHAR(10)
         ,  @c_LoadkeyEnd     NVARCHAR(10)= ''
         ,  @c_orderkey       NVARCHAR(10)=''
         ,  @c_Type           NVARCHAR(1) = ''
         ,  @c_DWCategory     NVARCHAR(1) = 'H'
         ,  @n_RecGroup       INT         = 0
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
         
   DECLARE   @c_A19               NVARCHAR(250)
            ,@c_A20               NVARCHAR(250)
            ,@c_A21               NVARCHAR(250)
            ,@c_A22               NVARCHAR(250)
            ,@c_A23               NVARCHAR(250)
            ,@c_A24               NVARCHAR(250)
            ,@c_B17               NVARCHAR(250)
            ,@c_B18               NVARCHAR(250)
            ,@c_B19               NVARCHAR(250)
            ,@c_B20               NVARCHAR(250)
            ,@c_B21               NVARCHAR(250)
            ,@c_B22               NVARCHAR(250)
          --  ,@c_storerkey NVARCHAR(20)
            ,@c_country          NVARCHAR(10)                 
            ,@c_ExecArguments    NVARCHAR(4000)        
            ,@c_sql              NVARCHAR(MAX)         
            ,@c_insertsql        NVARCHAR(MAX)         
            ,@c_chkCancelitem    NVARCHAR(5)           
            ,@c_OHORDkey         NVARCHAR(10) 
            ,@c_loadkey          NVARCHAR(20) 
            ,@c_GetLoadkey       NVARCHAR(20)         

   DECLARE @c_ExecStatements NVARCHAR(MAX)
   DECLARE @c_ExecStatements2 NVARCHAR(MAX)
   DECLARE @c_ExecWhere NVARCHAR(4000),@c_ExecHaving NVARCHAR(4000),@c_ExecOrderBy NVARCHAR(4000)  
   
   SET @c_ExecStatements = ''
   SET @c_ExecStatements2 = ''
   SET @c_ExecWhere = ''
   SET @n_NoOfLine = 15
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
   
    
   IF @c_DWCategory = 'D'
   BEGIN
      GOTO Detail
   END
   
   
   SELECT @c_country = nsqlvalue
   FROM NSQLCONFIG AS n WITH (NOLOCK)
   WHERE n.ConfigKey='COUNTRY'

   HEADER:

      CREATE TABLE #TMP_ORDH
            (  SeqNo          INT NOT NULL IDENTITY (1,1) PRIMARY KEY 
            ,  Orderkey       NVARCHAR(10) DEFAULT ('')
            ,  ORDSKU         NVARCHAR(20)
            ,  TotalPickQty   INT          DEFAULT (0)
            ,  TotalOrdQty    INT          DEFAULT (0)
            ,  RecGrp         INT
            ,  loadkey        NVARCHAR(10)
            ,  Storerkey      NVARCHAR(10)
            )

      SET @c_ExecWhere = ''
      IF ISNULL(RTRIM(@c_LoadkeyEnd), '') = '' AND ISNULL(RTRIM(@c_Orderkey),'') <> '' 
      BEGIN
         SET @c_ExecWhere = @c_ExecWhere + ' OH.Loadkey =  @c_LoadkeyStart AND OH.Orderkey = @c_orderkey AND OH.Storerkey = @c_storerkey '
      END

      IF ISNULL(RTRIM(@c_LoadkeyStart), '') <> '' AND ISNULL(RTRIM(@c_LoadkeyEnd), '') <> ''
      BEGIN
         IF ISNULL(LTRIM(RTRIM (@c_ExecWhere) ), '') <> ''
         BEGIN
            SET @c_ExecWhere = @c_ExecWhere + ' AND '
         END
         SET @c_ExecWhere = @c_ExecWhere + ' OH.Loadkey >=  @c_LoadkeyStart AND OH.Loadkey <=  @c_LoadkeyEnd AND OH.Storerkey = @c_storerkey '
         SET @c_ExecOrderBy = ' OH.Loadkey,PD.Orderkey'
      END

      ELSE
      BEGIN
         IF ISNULL(@c_type,'') <> ''
         BEGIN
            SET   @c_ExecHaving = 'HAVING 1 = CASE WHEN  @c_Type  = ''1'' AND SUM(PD.Qty) = 1  THEN 1' + CHAR(13)
                               +' WHEN @c_Type  = ''2'' AND SUM(PD.Qty) > 1 THEN 1 ' + CHAR(13)
                               + 'ELSE 1' + CHAR(13)
                               + 'END '
                               
            SET @c_ExecOrderBy = '  CASE WHEN SUM(PD.Qty) = 1 AND  @c_Type IN (''1'') THEN cast(LEN(CAST(MIN(LOC.Score) AS NVARCHAR(3))) AS NVARCHAR(5))+CAST(MIN(LOC.Score) AS NVARCHAR(3))+MIN(LOC.Logicallocation)+MIN(PD.Loc)+MIN(PD.Orderkey)'  + CHAR(13)                             
                             + '      WHEN SUM(PD.Qty) > 1 AND  @c_Type  IN (''2'') THEN Max(PD.Notes)+MIN(PD.Orderkey)+ Max(PD.Loc) ELSE '''' END'     + CHAR(1) 
         END
         ELSE
         BEGIN
            SET @c_ExecOrderBy = ' OH.Loadkey,PD.Orderkey'
         END   
      END   

      SET @c_ExecStatements = 'SELECT PD.Orderkey,'''' ' +
                  ',SUM(PD.Qty) ' +
                  ',SUM(OD.OriginalQty) ' +
                  ',(Row_Number() OVER (PARTITION BY OH.loadkey,PD.Orderkey ORDER BY OH.loadkey,PD.Orderkey Asc)-1)/' + CAST(@n_NoOfLine AS NVARCHAR(5) ) +' ' +
                  ',OH.Loadkey,OH.Storerkey ' + 
                  'FROM LOADPLANDETAIL LPD WITH (NOLOCK) ' +
                  'JOIN ORDERS OH WITH (NOLOCK)  ON OH.Orderkey = LPD.Orderkey   ' +
                  'JOIN ORDERDETAIL OD WITH (NOLOCK)  ON OD.Orderkey = LPD.Orderkey   ' +
                  'JOIN PICKDETAIL     PD  WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber) ' +
                  'JOIN LOC            LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc) ' +
                  'WHERE ' + @c_ExecWhere + CHAR(13) +
                  'GROUP BY OH.Loadkey,PD.Orderkey,OH.Storerkey ' + @c_ExecHaving + CHAR(13) +
                  'ORDER BY ' + @c_ExecOrderBy
            
         
     SET @c_insertsql = ' INSERT INTO #TMP_ORDH ' +
                        ' (  Orderkey' +
                        ' ,  ORDSKU' +
                        ' ,  TotalPickQty' +
                        ' ,  TotalOrdQty ' +
                        ',  RecGrp  ' +
                        ',  loadkey,Storerkey )'
                        
      SET @c_sql = @c_insertsql + CHAR(13) + @c_ExecStatements 
      
      SET @c_ExecArguments = N'   @c_LoadkeyStart       NVARCHAR(20)'    
                            +   ',@c_LoadkeyEnd         NVARCHAR(20)' 
                            +   ',@c_Orderkey           NVARCHAR(20)'
                            +   ',@c_Storerkey         NVARCHAR(20)'
                            +   ',@c_Type               NVARCHAR(20)' 
                       
                         
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_LoadkeyStart    
                        , @c_LoadkeyEnd
                        , @c_Orderkey
                        , @c_Storerkey
                        , @c_Type
                      
       SET @c_ExecStatements = ''
  
      SELECT @n_CntLine = MAX(RecGrp)
      FROM #TMP_ORDH
      WHERE loadkey >= @c_LoadkeyStart and loadkey <=@c_LoadkeyEnd

      CREATE TABLE #TMP_HDR
            (  SeqNo         INT 
            ,  Orderkey      NVARCHAR(10)          
            ,  A1            NVARCHAR(250)
            ,  A2            NVARCHAR(250)
            ,  A3            NVARCHAR(250)
            ,  A4            NVARCHAR(250)           
            ,  A6            NVARCHAR(4000) 
            ,  A7            NVARCHAR(18)
            ,  A11           NVARCHAR(250)
            ,  A12           NVARCHAR(250)
            ,  A13           NVARCHAR(250)
            ,  A14           NVARCHAR(250)
            ,  A15           NVARCHAR(20)
            ,  A16           NVARCHAR(10)
            ,  A17           NVARCHAR(4000)
            ,  A18_1         NVARCHAR(100)
            ,  A18_2         NVARCHAR(18) 
            ,  A18_3         NVARCHAR(45) 
            ,  A18_4         NVARCHAR(45) 
            ,  A18_5         NVARCHAR(45) 
            ,  A18_6         NVARCHAR(90)
            ,  B1            NVARCHAR(250)
            ,  B2            NVARCHAR(250)
            ,  B9            NVARCHAR(250)
            ,  B10           NVARCHAR(250)
            ,  B1101         NVARCHAR(250)     
            ,  B1102         NVARCHAR(250)      
            ,  B1103         NVARCHAR(250)     
            ,  B1104         NVARCHAR(250)     
            ,  B1105         NVARCHAR(250)     
            ,  B1106         NVARCHAR(250)     
            ,  B1107         NVARCHAR(250)     
            ,  B1108         NVARCHAR(250)     
            ,  B1109         NVARCHAR(250)     
            ,  B1110         NVARCHAR(250)     
            ,  RecGroup      INT
            ,  PNotes        NVARCHAR(250) 
            ,  OrdGrp        INT
            ,  A25           NVARCHAR(50)       
            ,  A26           NVARCHAR(50)       
            ,  A27           NVARCHAR(50)       
            ,  A28           NVARCHAR(50)               
            ,  C1            NVARCHAR(50)       
            ,  C2            NVARCHAR(50)       
            ,  C3            NVARCHAR(50)       
            ,  loadkey       NVARCHAR(20) 
            ,  Storerkey     NVARCHAR(10)
            ,  D01           NVARCHAR(250)     --CS01  
            )

        
         SET @c_ExecStatements = 'SELECT DISTINCT  TMP.Seqno' +
            ',OH.Orderkey ' +
            ',A1= CASE WHEN @c_country <> ''IN'' THEN OH.C_Company + ISNULL(MAX(CASE WHEN CL.Code =''A1'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +  
            ' ELSE ISNULL(MAX(CASE WHEN CL.Code =''A1'' THEN RTRIM(CL.Description) ELSE '''' END),'''') + space(2) + OH.C_Company END' +                                  
            ',A2=ISNULL(MAX(CASE WHEN CL.Code =''A2'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +
            ',A3=ISNULL(MAX(CASE WHEN CL.Code =''A3'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +
            ',A4=ISNULL(MAX(CASE WHEN CL.Code =''A4'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +
            ',A6=ISNULL(RTRIM(OH.Notes),'''') + '','' + ISNULL(RTRIM(OH.Notes2),'''') ' +
            ',A7=ISNULL(RTRIM(OH.UserDefine06),'''') ' +
            ',A11=ISNULL(MAX(CASE WHEN CL.Code =''A11'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +
            ',A12=ISNULL(MAX(CASE WHEN CL.Code =''A12'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +
            ',A13=ISNULL(MAX(CASE WHEN CL.Code =''A13'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +
            ',A14=ISNULL(MAX(CASE WHEN CL.Code =''A14'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +
            ',A15=ISNULL(RTRIM(OH.BuyerPO),'''') ' +
            ',A16=ISNULL(RTRIM(CONVERT(NVARCHAR(10),OH.OrderDate,112)),'''') ' + 
            ',A17=ISNULL(RTRIM(MAX(OH.Notes2)),'''') ' +
            ',A18_1=(ISNULL(RTRIM(OH.C_Company),'''') + ISNULL(RTRIM(ST.B_Contact2),'''') ) ' + 
            ',A18_2=ISNULL(RTRIM(OH.C_Zip),'''') ' + 
            ',A18_3=ISNULL(RTRIM(OH.C_State),'''') ' +
            ',A18_4=ISNULL(RTRIM(OH.C_City),'''') ' +
            ',A18_5=ISNULL(RTRIM(C_Address1),'''') ' +                                                                   
            ',A18_6=ISNULL(RTRIM(C_Address2),'''') + ISNULL(RTRIM(C_Address3),'''') + ISNULL(RTRIM(C_Address4),'''') ' +
            ',B1=ISNULL(MAX(CASE WHEN CL.Code =''B1'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +
            ',B2=ISNULL(MAX(CASE WHEN CL.Code =''B2'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' + 
            ',B9=ISNULL(MAX(CASE WHEN CL.Code =''B9'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +
            ',B10=ISNULL(MAX(CASE WHEN CL.Code =''B10'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +
            ',B1101=ISNULL(MAX(CASE WHEN CL.Code =''B1101'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +              
            ',B1102=ISNULL(MAX(CASE WHEN CL.Code =''B1102'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +              
            ',B1103=ISNULL(MAX(CASE WHEN CL.Code =''B1103'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +              
            ',B1104=ISNULL(MAX(CASE WHEN CL.Code =''B1104'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +              
            ',B1105=ISNULL(MAX(CASE WHEN CL.Code =''B1105'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +              
            ',B1106=ISNULL(MAX(CASE WHEN CL.Code =''B1106'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +              
            ',B1107=ISNULL(MAX(CASE WHEN CL.Code =''B1107'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +              
            ',B1108=ISNULL(MAX(CASE WHEN CL.Code =''B1108'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +              
            ',B1109=ISNULL(MAX(CASE WHEN CL.Code =''B1109'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +              
            ',B1110=ISNULL(MAX(CASE WHEN CL.Code =''B1110'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +              
            ',RecGroup=(Row_Number() OVER (PARTITION BY OH.Orderkey ORDER BY OH.Orderkey,  MIN(CONVERT(INT,OD.ExternLineNo)) Asc)-1)/' + CAST(@n_NoOfLine AS NVARCHAR(5)) +  ' ' + 
            ',PNotes=ISNULL(PD.notes,'''') ' + 
            ',OrdGrp=1 ' + 
            ',A25=ISNULL(MAX(CASE WHEN CL.Code = ''A25'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' + 
            ',A26=ISNULL(MAX(CASE WHEN CL.Code = ''A26'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' + 
            ',A27=ISNULL(MAX(CASE WHEN CL.Code = ''A27'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +  
            ',A28=ISNULL(MAX(CASE WHEN CL.Code = ''A28'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' + 
            ',C1=ISNULL(MAX(CASE WHEN CL.Code = ''C1'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' + 
            ',C2=ISNULL(MAX(CASE WHEN CL.Code = ''C2'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +  
            ',C3=ISNULL(MAX(CASE WHEN CL.Code = ''C3'' THEN RTRIM(CL.Description) ELSE '''' END),'''') ' +
            ',OH.loadkey,OH.Storerkey' +
            ',D01=ISNULL(MAX(CASE WHEN CL.Code =''D01'' THEN RTRIM(CL.Description) ELSE '''' END),'''') '   --CS01
         SET @c_ExecStatements2 =  ' FROM #TMP_ORDH TMP '+
            ' JOIN ORDERS OH WITH (NOLOCK) ON (TMP.Orderkey = OH.Orderkey AND TMP.loadkey = OH.loadkey)' +  
            'JOIN STORER ST WITH (NOLOCK) ON OH.Storerkey = ST.Storerkey ' + 
            'JOIN ORDERDETAIL OD WITH (NOLOCK) ON OH.Orderkey = OD.Orderkey ' + 
            'LEFT JOIN PICKDETAIL PD WITH (NOLOCK) ON ( OD.Orderkey = PD.Orderkey AND OD.sku = PD.sku ' + 
                                                          ' AND OD.Orderlinenumber = PD.Orderlinenumber ) ' + 
            'LEFT JOIN CODELKUP CL WITH (NOLOCK) ON ( CL.ListName= ''HMDN'' AND CL.Storerkey = OH.Storerkey ) ' + 
            ' WHERE ' + @c_ExecWhere +
            ' GROUP BY TMP.Seqno,OH.Orderkey,OH.loadkey' + 
            ',OH.Storerkey' + 
            ',OH.C_Company' +  
            ',ISNULL(RTRIM(OH.Notes),'''') ' + 
            ',ISNULL(RTRIM(OH.Notes2),'''') ' +  
            ',ISNULL(RTRIM(OH.UserDefine06),'''')  ' + 
            ',ISNULL(RTRIM(Substring(OD.SKU,1,7)),'''') ' + 
            ',ISNULL(RTRIM(Substring(OD.SKU,8,3)),'''') ' +
            ',ISNULL(RTRIM(Substring(OD.SKU,11,3)),'''') ' +  
            ',ISNULL(RTRIM(OH.BuyerPO),'''') ' +  
            ',ISNULL(RTRIM(CONVERT(NVARCHAR(10),OH.OrderDate,112)),'''') ' +    
            ',ISNULL(RTRIM(OH.C_Company),'''') ' +  
            ',ISNULL(RTRIM(ST.B_Contact2),'''') ' +  
            ',ISNULL(RTRIM(OH.C_state),'''') ' +  
            ',ISNULL(RTRIM(OH.C_Zip),'''') ' + 
            ',ISNULL(RTRIM(OH.C_City),'''') ' +  
            ',ISNULL(RTRIM(C_Address1),'''') ' +                               
            ',ISNULL(RTRIM(C_Address2),'''') ' +  
            ',ISNULL(RTRIM(C_Address3),'''') ' +  
            ',ISNULL(RTRIM(C_Address4),'''') ' +  
            ',ISNULL(PD.notes,'''') ' + 
             ' ORDER BY TMP.Seqno '

  
    SET @c_insertsql = 'INSERT INTO #TMP_HDR'+            
           '(  seqno     '+                           
           ',  Orderkey  '+                           
           ',  A1        '+                           
           ',  A2        '+                           
           ',  A3        '+                           
           ',  A4        '+                           
           ',  A6        '+                           
           ',  A7        '+                           
           ',  A11       '+                           
           ',  A12       '+                           
           ',  A13       '+                           
           ',  A14       '+                           
           ',  A15       '+                           
           ',  A16       '+                           
           ',  A17       '+                           
           ',  A18_1     '+                           
           ',  A18_2     '+                           
           ',  A18_3     '+                           
           ',  A18_4     '+                           
           ',  A18_5     '+                           
           ',  A18_6     '+                           
           ',  B1        '+                           
           ',  B2        '+                           
           ',  B9        '+                           
           ',  B10       '+                           
           ',  B1101     '+                      
           ',  B1102     '+                      
           ',  B1103     '+                      
           ',  B1104     '+                      
           ',  B1105     '+                      
           ',  B1106     '+                      
           ',  B1107     '+                      
           ',  B1108     '+                      
           ',  B1109     '+                      
           ',  B1110     '+                      
           ',  RecGroup  '+                           
           ',  PNotes    '+                           
           ',  OrdGrp    '+                           
           ',  A25       '+                    
           ',  A26       '+                    
           ',  A27       '+                    
           ',  A28       '+                    
           ',  C1        '+                           
           ',  C2        '+                           
           ',  C3        '+  
           ',  loadkey   '+      
           ',  Storerkey '+    
           ',  D01       '+           --CS01               
           ')            '                          
               
                                  
      SET @c_sql = @c_insertsql + CHAR(13) + @c_ExecStatements +  @c_ExecStatements2
      
      SET @c_ExecArguments = N'   @c_country          NVARCHAR(10)'    
                            +   ',@c_LoadkeyStart     NVARCHAR(20)'    
                            +   ',@c_LoadkeyEnd       NVARCHAR(20)' 
                            +   ',@c_Orderkey           NVARCHAR(20)'
                            +   ',@c_Storerkey         NVARCHAR(20)'
                            +   ',@c_Type             NVARCHAR(20)' 
                       
     --  print  @c_SQL                 
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_country    
                        , @c_LoadkeyStart    
                        , @c_LoadkeyEnd
                        , @c_orderkey
                        , @c_Storerkey
                        , @c_Type

                 IF @b_debug = 1
                 BEGIN
                    INSERT INTO TRACEINFO (TraceName, timeIn, Step1, Step2, step3, step4, step5)
                    VALUES ('isp_Delivery_Note42_RDT', getdate(), @c_DWCategory, @c_LoadkeyStart, @c_LoadkeyEnd, @c_Storerkey, suser_name())
                 END


   DECLARE CUR_OrderLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT loadkey,Orderkey   
   FROM   #TMP_HDR ORD   
   WHERE loadkey >=  @c_LoadkeyStart AND loadkey <=@c_LoadkeyEnd
   AND Storerkey = @c_Storerkey
   Order by loadkey,Orderkey
  
   OPEN CUR_OrderLoop   
     
   FETCH NEXT FROM CUR_OrderLoop INTO @c_loadkey,@c_OHORDkey    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   
      
      SET @c_chkCancelitem='N'
      
      IF EXISTS (SELECT 1
                 FROM ORDERS O WITH (NOLOCK)
                 JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=O.OrderKey
                 WHERE O.[Status] <> 0
                 AND OD.OpenQty > 0
                 AND OD.QtyAllocated = 0
                 AND OD.QtyPicked   = 0
                 AND OD.OrderKey=@c_OHORDkey
                 AND O.LoadKey =@c_loadkey
                 AND O.StorerKey=@c_Storerkey)
       BEGIN
         SET @c_chkCancelitem = 'Y'
       END  
       
    IF @c_chkCancelitem='N'
    BEGIN
      
      UPDATE #TMP_HDR
      SET A13 = ''
      WHERE Orderkey = @c_OHORDkey  
      AND loadkey = @c_loadkey
      AND Storerkey = @c_Storerkey
      
    END              

      
   FETCH NEXT FROM CUR_OrderLoop INTO @c_loadkey,@c_OHORDkey  
   END   
      

      SELECT @n_CntTTLLine = MAX(OrdGrp)
      FROM #TMP_HDR
      WHERE Orderkey = @c_OHORDkey AND loadkey = @c_loadkey and Storerkey = @c_Storerkey

WHILE @n_CntLine > @n_CntTTLLine --OR @n_NoOfPage > 1
BEGIN

INSERT INTO #TMP_HDR(Orderkey  
            ,  A1            
            ,  A2           
            ,  A3            
            ,  A4            
            ,  A6             
            ,  A7                    
            ,  A11           
            ,  A12           
            ,  A13           
            ,  A14           
            ,  A15           
            ,  A16           
            ,  A17           
            ,  A18_1         
            ,  A18_2         
            ,  A18_3         
            ,  A18_4          
            ,  A18_5         
            ,  A18_6  
            ,  B1
            ,  B2
            ,  B9
            ,  B10
            ,  B1101
            ,  B1102
            ,  B1103
            ,  B1104
            ,  B1105
            ,  B1106
            ,  B1107
            ,  B1108
            ,  B1109
            ,  B1110          
            ,  RecGroup
            ,  Pnotes
            ,  OrdGrp
            ,  A25              
            ,  A26              
            ,  A27              
            ,  A28              
            , C1
            , C2
            , C3  
            , loadkey  
            , Storerkey
            , D01                   --CS01
             )
SELECT Orderkey  
            ,  A1            
            ,  A2           
            ,  A3            
            ,  A4            
            ,  A6             
            ,  A7                    
            ,  A11           
            ,  A12           
            ,  A13           
            ,  A14           
            ,  A15           
            ,  A16           
            ,  A17           
            ,  A18_1         
            ,  A18_2         
            ,  A18_3         
            ,  A18_4          
            ,  A18_5         
            ,  A18_6  
            ,  B1
            ,  B2
            ,  B9
            ,  B10
            ,  B1101
            ,  B1102
            ,  B1103
            ,  B1104
            ,  B1105
            ,  B1106
            ,  B1107
            ,  B1108
            ,  B1109
            ,  B1110               
            ,  @n_RecNo 
            ,  Pnotes
            ,  OrdGrp
            ,  A25              
            ,  A26              
            ,  A27              
            ,  A28              
            ,  C1
            ,  C2
            ,  C3  
            ,  loadkey
            ,  storerkey
            ,  D01                  --CS01
  FROM #TMP_HDR
  WHERE seqno = 1

 SET @n_RecNo = @n_RecNo + 1
 SET @n_CntLine = @n_CntLine -1
 
END

      DECLARE CUR_PageLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT loadkey,Orderkey 
      FROM   #TMP_HDR
      WHERE loadkey= @c_LoadkeyStart
      AND Orderkey = CASE WHEN ISNULL(@c_orderkey,'') <> '' THEN @c_orderkey ELSE Orderkey END
      AND Storerkey = @c_Storerkey
      ORDER BY loadkey,Orderkey     

      OPEN CUR_PageLoop   
     
      FETCH NEXT FROM CUR_PageLoop INTO @c_Getloadkey , @c_GetOrderkey  
     
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
      SET @n_NoOfPage = 1

     SELECT @n_cntPNote = Count (DISTINCT pnotes)
            ,@n_seqno   = MIN (seqno)
     FROM #TMP_HDR
     WHERE orderkey=@c_GetOrderkey
     AND loadkey = @c_Getloadkey
     AND Storerkey = @c_Storerkey

      SELECT @n_NoOfPage = COUNT(DISTINCT caseid)
      FROM pickdetail (NOLOCK)
      WHERE orderkey=@c_GetOrderkey

      IF @n_cntPNote > 1
      BEGIN
  
        DELETE #TMP_HDR
        WHERE orderkey=@c_GetOrderkey
      AND loadkey = @c_Getloadkey
        AND seqno=@n_seqno
      AND Storerkey = @c_Storerkey


      END 

       SET @n_totalPage = @n_NoOfPage

       WHILE @n_NoOfPage >= 2
       BEGIN
         INSERT INTO #TMP_HDR (Orderkey  
            ,  A1            
            ,  A2           
            ,  A3            
            ,  A4            
            ,  A6             
            ,  A7                    
            ,  A11           
            ,  A12           
            ,  A13           
            ,  A14           
            ,  A15           
            ,  A16           
            ,  A17           
            ,  A18_1         
            ,  A18_2         
            ,  A18_3         
            ,  A18_4          
            ,  A18_5         
            ,  A18_6  
            ,  B1
            ,  B2
            ,  B9
            ,  B10
            ,  B1101
            ,  B1102
            ,  B1103
            ,  B1104
            ,  B1105
            ,  B1106
            ,  B1107
            ,  B1108
            ,  B1109
            ,  B1110 
            ,  RecGroup
            ,  PNotes
            ,  OrdGrp
            ,  A25              
            ,  A26              
            ,  A27              
            ,  A28              
            ,  C1
            ,  C2
            ,  C3  
            ,  loadkey
            ,  Storerkey
            ,  D01                        --CS01
            )
         SELECT Orderkey  
            ,  A1            
            ,  A2           
            ,  A3            
            ,  A4            
            ,  A6             
            ,  A7                    
            ,  A11           
            ,  A12           
            ,  A13           
            ,  A14           
            ,  A15           
            ,  A16           
            ,  A17           
            ,  A18_1         
            ,  A18_2         
            ,  A18_3         
            ,  A18_4          
            ,  A18_5         
            ,  A18_6  
            ,  B1
            ,  B2
            ,  B9
            ,  B10
            ,  B1101
            ,  B1102
            ,  B1103
            ,  B1104
            ,  B1105
            ,  B1106
            ,  B1107
            ,  B1108
            ,  B1109
            ,  B1110 
            ,  RecGroup
            ,  PNotes
            ,  @n_CurrGrp
            ,  A25              
            ,  A26              
            ,  A27              
            ,  A28              
            ,  C1
            ,  C2
            ,  C3  
            ,  loadkey
            ,  Storerkey
            ,  D01                      --CS01
         FROM #TMP_HDR 
         WHERE ORDERKEY = @c_GetOrderkey 
         AND loadkey = @c_Getloadkey
         AND Storerkey = @c_Storerkey
         AND Ordgrp = 1       

       SET @n_NoOfPage = @n_NoOfPage - 1
       SET @n_CurrGrp = @n_CurrGrp + 1

       IF @n_NoOfPage = 1 
        BREAK;
       END
  
       FETCH NEXT FROM CUR_PageLoop INTO @c_Getloadkey,@c_GetOrderkey  
       END   
  
     CLOSE CUR_PageLoop
   
      SELECT * FROM #TMP_HDR
      --ORDER BY pnotes,orderkey,OrdGrp 
      ORDER BY seqno
   
      GOTO QUIT_SP

 DETAIL:

  CREATE TABLE #TMP_ORDDET
            (  SeqNo          INT IDENTITY (1,1)
            ,  serialno       INT NULL
            ,  Orderkey       NVARCHAR(10) DEFAULT ('')
            ,  sku            NVARCHAR(20) 
            ,  ODNotes        NVARCHAR(200)
            ,  ODUserDef06    NVARCHAR(17)
            ,  TotalPickQty   INT           NULL   
            ,  TotalOrdQty    INT           NULL
            ,  RecGroup       INT           NULL
            ,  A19           NVARCHAR(50)   NULL     
            ,  A20           NVARCHAR(50)   NULL     
            ,  A21           NVARCHAR(50)   NULL      
            ,  A22           NVARCHAR(50)   NULL      
            ,  A23           NVARCHAR(50)   NULL      
            ,  A24           NVARCHAR(50)   NULL           
            ,  B17           NVARCHAR(50)   NULL      
            ,  B18           NVARCHAR(50)   NULL      
            ,  B19           NVARCHAR(50)   NULL      
            ,  B20           NVARCHAR(50)   NULL      
            ,  B21           NVARCHAR(50)   NULL      
            ,  B22           NVARCHAR(50)   NULL    
            ,  loadkey       NVARCHAR(20)   NULL  
            )


            SET  @c_A19   = ''
            SET  @c_A20  = ''
            SET  @c_A21  = ''
            SET  @c_A22  = ''
            SET  @c_A23  = ''
            SET  @c_A24  = ''
            SET  @c_B17  = ''
            SET  @c_B18  = ''
            SET  @c_B19  = ''
            SET  @c_B20  = ''
            SET  @c_B21  = ''
            SET  @c_B22  = ''
            --SET @c_storerkey = ''
            
   --         SELECT TOP 1 @c_storerkey = Storerkey
   --         FROM ORDERS (NOLOCK)       
   --         WHERE LoadKey = @c_LoadkeyStart 
         --AND Orderkey = CASE WHEN ISNULL(@c_Orderkey,'') <> '' THEN @c_Orderkey ELSE Orderkey END     
            
         SELECT  @c_A19        = ISNULL(MAX(CASE WHEN CL.Code = 'A19' THEN RTRIM(CL.Description) ELSE '' END),'')
                ,@c_A20        = ISNULL(MAX(CASE WHEN CL.Code = 'A20' THEN RTRIM(CL.Description) ELSE '' END),'') 
                ,@c_A21        = ISNULL(MAX(CASE WHEN CL.Code = 'A21' THEN RTRIM(CL.Description) ELSE '' END),'')
                ,@c_A22        = ISNULL(MAX(CASE WHEN CL.Code = 'A22' THEN RTRIM(CL.Description) ELSE '' END),'')
                ,@c_A23        = ISNULL(MAX(CASE WHEN CL.Code = 'A23' THEN RTRIM(CL.Description) ELSE '' END),'')
                ,@c_A24        = ISNULL(MAX(CASE WHEN CL.Code = 'A24' THEN RTRIM(CL.Description) ELSE '' END),'') 
                ,@c_B17        = ISNULL(MAX(CASE WHEN CL.Code = 'B17' THEN RTRIM(CL.Description) ELSE '' END),'')
                ,@c_B18        = ISNULL(MAX(CASE WHEN CL.Code = 'B18' THEN RTRIM(CL.Description) ELSE '' END),'') 
                ,@c_B19        = ISNULL(MAX(CASE WHEN CL.Code = 'B19' THEN RTRIM(CL.Description) ELSE '' END),'')
                ,@c_B20        = ISNULL(MAX(CASE WHEN CL.Code = 'B20' THEN RTRIM(CL.Description) ELSE '' END),'')
                ,@c_B21       = ISNULL(MAX(CASE WHEN CL.Code = 'B21' THEN RTRIM(CL.Description) ELSE '' END),'')
                ,@c_B22       = ISNULL(MAX(CASE WHEN CL.Code = 'B22' THEN RTRIM(CL.Description) ELSE '' END),'')
         FROM CODELKUP CL WITH (NOLOCK) 
         WHERE (CL.ListName = 'HMDN' AND CL.Storerkey = @c_Storerkey)
    
         IF ISNULL(@c_Orderkey,'') <> ''
         BEGIN
            INSERT INTO #TMP_ORDDET
               (  serialno
               ,  Orderkey
               ,  SKU
               ,  ODNotes
               ,  ODUserDef06
               ,  TotalPickQty
               ,  TotalOrdQty
               ,  RecGroup
               ,  A19              
               ,  A20              
               ,  A21              
               ,  A22              
               ,  A23              
               ,  A24            
               ,  B17              
               ,  B18              
               ,  B19              
               ,  B20              
               ,  B21              
               ,  B22     
               ,  Loadkey          
                 )
            SELECT serialno = Row_Number() OVER (PARTITION BY OD.Orderkey ORDER BY OD.Orderkey Asc)
                  ,OD.Orderkey
                  ,ISNULL(RTRIM(Substring(OD.SKU,1,7)),'')  + '-' +  ISNULL(RTRIM(Substring(OD.SKU,8,3)),'')
                          + '-' +  ISNULL(RTRIM(Substring(OD.SKU,11,3)),'') 
                  ,ISNULL(RTRIM(OD.Notes),'') + CASE WHEN ISNULL(RTRIM(OD.Notes2),'') <> '' THEN ',' ELSE '' END
                   + space(2) +ISNULL(RTRIM(OD.Notes2),'')
                  ,ISNULL(RTRIM(OD.UserDefine06),'') 
                  ,SUM(ISNULL(PD.Qty,0))
                  ,SUM(OD.OriginalQty)
                  ,(Row_Number() OVER (PARTITION BY LPD.loadkey,OD.Orderkey ORDER BY LPD.loadkey,OD.Orderkey Asc)-1)/@n_NoOfLine
                  ,@c_A19
                  ,@c_A20
                  ,@c_A21
                  ,@c_A22
                  ,@c_A23
                  ,@c_A24
                  ,@c_B17
                  ,@c_B18
                  ,@c_B19
                  ,@c_B20
                  ,@c_B21
                  ,@c_B22
                  ,LPD.loadkey
            FROM LOADPLANDETAIL LPD WITH (NOLOCK)
            JOIN ORDERDETAIL OD WITH (NOLOCK)  ON OD.Orderkey = LPD.Orderkey 
            LEFT OUTER JOIN PICKDETAIL  PD  WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey AND OD.sku = PD.sku 
                                                         AND OD.Orderlinenumber = PD.Orderlinenumber)
            LEFT OUTER JOIN LOC   LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)
            WHERE OD.Orderkey = @c_Orderkey 
            AND LPD.loadkey = @c_LoadkeyStart
            AND OD.storerkey = @c_Storerkey
            GROUP BY LPD.loadkey,OD.Orderkey,OD.SKU,ISNULL(RTRIM(OD.UserDefine06),''),OD.Notes,OD.Notes2 
            ORDER BY LPD.loadkey,OD.Orderkey
         END
         ELSE
         BEGIN
            INSERT INTO #TMP_ORDDET
               (  serialno
               ,  Orderkey
               ,  SKU
               ,  ODNotes
               ,  ODUserDef06
               ,  TotalPickQty
               ,  TotalOrdQty
               ,  RecGroup
               ,  A19              
               ,  A20              
               ,  A21              
               ,  A22              
               ,  A23              
               ,  A24            
               ,  B17              
               ,  B18              
               ,  B19              
               ,  B20              
               ,  B21              
               ,  B22   
               ,  loadkey            
               )
            SELECT serialno = Row_Number() OVER (PARTITION BY OD.Orderkey ORDER BY OD.Orderkey Asc)
                  ,OD.Orderkey
                  ,ISNULL(RTRIM(Substring(OD.SKU,1,7)),'')  + '-' +  ISNULL(RTRIM(Substring(OD.SKU,8,3)),'')
                             + '-' +  ISNULL(RTRIM(Substring(OD.SKU,11,3)),'') 
                  ,ISNULL(RTRIM(OD.Notes),'') + CASE WHEN ISNULL(RTRIM(OD.Notes2),'') <> '' THEN ',' ELSE '' END
                   + space(2) +ISNULL(RTRIM(OD.Notes2),'')
                  ,ISNULL(RTRIM(OD.UserDefine06),'') 
                  ,SUM(ISNULL(PD.Qty,0))
                  ,SUM(OD.OriginalQty)
                  ,(Row_Number() OVER (PARTITION BY LPD.loadkey,OD.Orderkey ORDER BY LPD.loadkey,OD.Orderkey Asc)-1)/@n_NoOfLine
                  ,@c_A19
                  ,@c_A20
                  ,@c_A21
                  ,@c_A22
                  ,@c_A23
                  ,@c_A24
                  ,@c_B17
                  ,@c_B18
                  ,@c_B19
                  ,@c_B20
                  ,@c_B21
                  ,@c_B22
                  ,LPD.loadkey
            FROM LOADPLANDETAIL LPD WITH (NOLOCK)
            JOIN ORDERDETAIL OD WITH (NOLOCK)  ON OD.Orderkey = LPD.Orderkey 
            LEFT OUTER JOIN PICKDETAIL  PD  WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey AND OD.sku = PD.sku 
                                                         AND OD.Orderlinenumber = PD.Orderlinenumber)
            LEFT OUTER JOIN LOC   LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)
            WHERE LPD.loadkey = @c_LoadkeyStart
            GROUP BY LPD.loadkey,OD.Orderkey,OD.SKU,ISNULL(RTRIM(OD.UserDefine06),''),OD.Notes,OD.Notes2 
            ORDER BY LPD.loadkey,OD.Orderkey

         END


     SELECT @n_TotDetail = COUNT(1)
            ,@n_SerialNo  = MAX(SerialNo)
      FROM #TMP_ORDDET
      WHERE #TMP_ORDDET.RecGroup = @n_RecGroup

    

      IF @n_NoOfLine > @n_TotDetail
      BEGIN
         SET @n_LineNeed = @n_NoOfLine - ( @n_SerialNo % @n_NoOfLine )
        
         WHILE @n_LineNeed > 0
         BEGIN
            SET @n_TotDetail = @n_TotDetail + 1
            SET @n_SerialNo = @n_SerialNo + 1
            INSERT INTO #TMP_ORDDET (serialno,  Orderkey,sku, ODUserDef06,ODNotes,RecGroup )
            VALUES (@n_SerialNo,'','','','',@n_RecGroup)
            SET @n_LineNeed = @n_LineNeed - 1  
         END
      END 

 SELECT * FROM #TMP_ORDDET
 WHERE RecGroup = @n_RecGroup
 Order by serialno
     
  GOTO QUIT_SP

 -- DROP TABLE #TMP_ORD
  DROP TABLE #TMP_HDR
  DROP TABLE #TMP_ORDH

   QUIT_SP:
END       
      

GO