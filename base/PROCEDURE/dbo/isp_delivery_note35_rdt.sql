SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_Delivery_Note35_rdt                             */
/* Creation Date: 2019-03-11                                             */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: WMS-8238 - KR_Nike_Workorder_Datawindow_New                  */
/*                                                                       */
/* Called By: r_dw_delivery_note35_rdt                                   */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver   Purposes                                   */
/* 07-JUL-2020  CSCHONG 1.1   WMS-13891 - Revised field mapping (CS01)   */
/* 22-JUL-2021  CSCHONG 1.2   WMS-17184 revised sku field logic (CS02)   */
/*************************************************************************/

CREATE PROC [dbo].[isp_Delivery_Note35_rdt] 
         (  @c_Orderkey    NVARCHAR(10)
         ,  @c_Loadkey     NVARCHAR(10)= ''
         ,  @c_Type        NVARCHAR(1) = ''
         )           
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_NoOfLine        INT
         , @n_TotDetail       INT
         , @n_LineNeed        INT
         , @n_SerialNo        INT
         , @b_debug           INT
         , @c_DelimiterSign   NVARCHAR(1)
         , @n_Count           int
         , @c_GetOrdkey       NVARCHAR(20)
         , @c_sku             NVARCHAR(20)
         , @c_ODUDF0102       NVARCHAR(120)
         , @n_seqno           INT
         , @c_ColValue        NVARCHAR(250)  --CS01   
         , @c_SStyle          NVARCHAR(50)
         , @c_SColor          NVARCHAR(50)
         , @c_SSize           NVARCHAR(50)
         , @n_maxLine         INT

   --CS01 START
DECLARE  @c_getorderkey         NVARCHAR(20)
       , @c_OrdInfoData         NVARCHAR(4000)
       , @c_2ndDelimiterSign    NVARCHAR(5)
       , @n_2ndSeqNo            INT
       , @c_2ndColValue         NVARCHAR(150)
       , @c_Col01               NVARCHAR (250)
       , @c_Col02               NVARCHAR (250)
       , @c_Col03               NVARCHAR (250)
       , @c_Col04               NVARCHAR (250)
       , @c_rptcol05            NVARCHAR (250)
       , @c_rptcol07            NVARCHAR (250)
   --CS01 END
   
   SET @n_NoOfLine = 15
   SET @n_TotDetail= 0
   SET @n_LineNeed = 0
   SET @n_SerialNo = 0
   SET @b_debug    = 0
   SET @c_OrdInfoData = ''            --CS01
   SET @c_DelimiterSign = '|'         --CS01
   SET @c_2ndDelimiterSign = ';'      --CS01


      CREATE TABLE #TMP_ORD35
            (  SeqNo          INT IDENTITY (1,1)
            ,  Orderkey       NVARCHAR(10) DEFAULT ('')
            ,  OrdLineNumber  NVARCHAR(10) DEFAULT ('')
            ,  SKU            NVARCHAR(20) DEFAULT ('')
            ,  TotalQty       INT         DEFAULT (0)
            ,  RecGrp         INT         DEFAULT(0)
          
            )

      CREATE TABLE #TMP_HDR35
            (  SeqNo         INT            
            ,  Orderkey      NVARCHAR(10) NULL
            ,  Storerkey     NVARCHAR(15) NULL
            ,  OrdLineNumber NVARCHAR(10) NULL
            ,  m_company     NVARCHAR(45) NULL
            ,  C1Long        NVARCHAR(150) NULL
            ,  C2Long        NVARCHAR(150) NULL
            ,  SKU           NVARCHAR(120) NULL
            ,  Lottable08    NVARCHAR(30) NULL
            ,  Lottable09    NVARCHAR(30) NULL
            ,  Qty           INT  NULL
            ,  RecGrp        INT NULL              
            ,  C_Contact1    NVARCHAR(45) NULL
            ,  ODNotes       NVARCHAR(120) NULL
            ,  [RptCol05]    NVARCHAR (250) NULL            --CS01
            ,  [RptCol07]    NVARCHAR (250) NULL            --CS01
            ,  [RptCol03]    NVARCHAR (250) NULL            --CS01
         )

         --CS01 START
        CREATE TABLE [#TempSPLITORDINFO] (  
                     [SeqNo]        [INT] IDENTITY(1,1) NOT NULL ,   
                     [Orderkey]     INT,  
                     [DocInfoData]  NVARCHAR(250) NULL, 
                     [Col01]        [NVARCHAR] (250) NULL,
                     [Col02]        [NVARCHAR] (250) NULL,
                     [Col03]        [NVARCHAR] (250) NULL,
                     [Col04]        [NVARCHAR] (250) NULL,
                     [RptCol05]     [NVARCHAR] (250) NULL,
                     [RptCol07]     [NVARCHAR] (250) NULL )  
         --CS01 END

      IF ISNULL(RTRIM(@c_Orderkey),'') = ''
      BEGIN
        
        INSERT INTO #TMP_ORD35
            (  Orderkey
            , OrdLineNumber
            ,  SKU
            ,  TotalQty
            ,  RecGrp
            )
         SELECT DISTINCT OH.Orderkey
                        ,OD.OrderLineNumber
                       -- ,OD.sku                     --CS02
                        ,Sku.sku                       --CS02
                        ,Sum(OD.originalqty)
                        ,(Row_Number() OVER (PARTITION BY OH.Orderkey ORDER BY OH.Orderkey,Sku.sku Asc)-1)/@n_NoOfLine + 1 AS recgrp   --CS02
         FROM Orders OH  WITH (NOLOCK) 
         JOIN OrderDetail OD (NOLOCK) ON OD.StorerKey = OH.StorerKey
                                      AND OD.Orderkey  = OH.OrderKey
         JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku                                  --CS02
         JOIN SKU S1 (NOLOCK) ON S1.ALTSKU=SKU.ALTSKU AND S1.StorerKey='NIKEKRB' AND SKU.StorerKey='NIKEKR'      --CS02
         WHERE OH.Loadkey = @c_Loadkey
         GROUP BY OH.Orderkey, OD.OrderLineNumber ,Sku.sku --,OD.sku                                              --CS02
       ORDER BY   OH.Orderkey, OD.OrderLineNumber ,Sku.sku --OD.sku                                               --CS02

      END 
      ELSE
      BEGIN
          INSERT INTO #TMP_ORD35
            (  Orderkey
            , OrdLineNumber
            ,  SKU
            ,  TotalQty
            ,  RecGrp
            )
         SELECT DISTINCT OH.Orderkey
                       , OD.OrderLineNumber
                       --,OD.sku                                           --CS02
                       ,Sku.sku                                            --CS02
                       ,Sum(OD.originalqty)
                       ,(Row_Number() OVER (PARTITION BY OH.Orderkey ORDER BY OH.Orderkey,Sku.sku Asc)-1)/@n_NoOfLine + 1 AS recgrp    --CS02
         FROM Orders OH  WITH (NOLOCK) 
         JOIN OrderDetail OD (NOLOCK) ON OD.StorerKey = OH.StorerKey
                                      AND OD.Orderkey  = OH.OrderKey
         JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku                                  --CS02
         JOIN SKU S1 (NOLOCK) ON S1.ALTSKU=SKU.ALTSKU AND S1.StorerKey='NIKEKRB' AND SKU.StorerKey='NIKEKR'      --CS02
         WHERE OH.orderkey = @c_orderkey
         GROUP BY OH.Orderkey ,Sku.sku --OD.sku    --CS02
                , OD.OrderLineNumber
       ORDER BY   OH.Orderkey , OD.OrderLineNumber,Sku.sku --OD.sku    --CS02
      END

      --CS01 START
      
      DECLARE CUR_ORDLOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT Orderkey   
      FROM   #TMP_ORD35 ORD     
  
      OPEN CUR_ORDLOOP   
     
      FETCH NEXT FROM CUR_ORDLOOP INTO @c_getorderkey    
     
      WHILE @@FETCH_STATUS <> -1  
      BEGIN 
     
      SET @c_OrdInfoData = ''

      SELECT @c_OrdInfoData = OIF.Data
      FROM Docinfo OIF WITH (NOLOCK)
      WHERE OIF.key1 =  @c_getorderkey


     DECLARE C_DelimSplit CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT SeqNo, ColValue   
         FROM dbo.fnc_DelimSplit(@c_DelimiterSign,@c_OrdInfoData)  
  
         OPEN C_DelimSplit  
         FETCH NEXT FROM C_DelimSplit INTO @n_SeqNo, @c_ColValue  
  
           WHILE (@@FETCH_STATUS=0)   
           BEGIN  
               
           INSERT INTO #TempSPLITORDINFO (Orderkey,DocInfoData)  
                          VALUES (@c_getorderkey,@c_ColValue)  

            DECLARE C_2ndDelimSplit CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT SeqNo, ColValue   
               FROM dbo.fnc_DelimSplit(@c_2ndDelimiterSign,@c_ColValue)  
  
               OPEN C_2ndDelimSplit  
               FETCH NEXT FROM C_2ndDelimSplit INTO @n_2ndSeqNo, @c_2ndColValue  
  
                 WHILE (@@FETCH_STATUS=0)   
                 BEGIN 

                        IF @n_2ndSeqNo = 1
                        BEGIN
                            SET @c_Col01 = @c_2ndColValue
                        END
                        ELSE IF @n_2ndSeqNo = 2
                        BEGIN
                            SET @c_Col02 = @c_2ndColValue

                           SELECT @c_rptcol05 = ISNULL(C.long,'') 
                           FROM Codelkup C WITH (nolock) 
                           WHERE C.listname = 'PRESSSTYLE' 
                           AND C.code =   @c_Col02  
                        END
                        ELSE IF @n_2ndSeqNo = 3
                        BEGIN
                            SET @c_Col03 = @c_2ndColValue
                        END
                        ELSE IF @n_2ndSeqNo = 4
                        BEGIN
                            SET @c_Col04 = @c_2ndColValue
                            
                             SELECT @c_rptcol07= ISNULL(C.Long,'')
                             FROM Codelkup C WITH (nolock) 
                             WHERE C.listname = 'PRESSLOC' 
                             AND C.code = RIGHT(@c_Col04,3) 
                        END 
                         

              FETCH NEXT FROM C_2ndDelimSplit INTO @n_2ndSeqNo, @c_2ndColValue  
              END   
  
              CLOSE C_2ndDelimSplit  
              DEALLOCATE C_2ndDelimSplit

               UPDATE #TempSPLITORDINFO 
                          SET Col01 = @c_Col01
                             ,Col02 = @c_Col02
                             ,Col03 = @c_Col03
                             ,Col04 = @c_Col04
                             ,RptCol05 = @c_rptcol05
                             ,RptCol07 = SUBSTRING(@c_Col04,1,LEN(@c_Col04)-3)+ @c_rptcol07
                          WHERE Orderkey = @c_getorderkey
                          AND Docinfodata = @c_ColValue 
               
                 SET @c_Col01 = ''
                 SET @c_Col02 = ''
                 SET @c_Col03 = ''
                 SET @c_Col04 = ''
                 SET @c_rptcol05 = ''
                 SET @c_rptcol07 = ''   
  
            FETCH NEXT FROM C_DelimSplit INTO @n_SeqNo, @c_ColValue  
            END   
  
            CLOSE C_DelimSplit  
            DEALLOCATE C_DelimSplit   

      FETCH NEXT FROM CUR_ORDLOOP INTO @c_getorderkey 
      END   
  
      CLOSE CUR_ORDLOOP  
      DEALLOCATE CUR_ORDLOOP

      --CS01 END

      INSERT INTO #TMP_HDR35
            (  SeqNo      
            ,  Orderkey   
            ,  Storerkey 
            ,  OrdLineNumber 
            ,  m_company   
            ,  C1Long     
            ,  C2Long     
            ,  SKU        
            ,  Lottable08        
            ,  Lottable09  
            ,  Qty        
            ,  RecGrp                     
            ,  C_Contact1  
            ,  ODNotes 
            ,  RptCol05            --CS01
            ,  RptCol07            --CS01 
            ,  RptCol03            --CS01
         )
      SELECT DISTINCT 
             TMPOIF.SeqNo        --CS01
            ,OH.orderkey
            ,OH.Storerkey
            ,OD.OrderLineNumber
            ,OH.M_Company
            ,C1Long   = ISNULL(C1.long,'')  
            ,C2Long   = ISNULL(C2.long,'') 
            ,SKU        = TMP.SKU
            ,Lottable08 = OD.Lottable08
            ,Lottable09  = OD.Lottable09
            ,Qty        = TMP.TotalQty
            ,RecGrp     = TMP.Recgrp
            ,C_Contact1 = ISNULL(oh.c_contact1,'')
           -- ,ODNotes     = ISNULL(OD.notes,'')                --CS01
            ,ODNotes    = ISNULL(TMPOIF.col01,'')                 --CS01 
            ,RptCol05   = ISNULL(TMPOIF.rptcol05,'')              --CS01
            ,RptCol07   = ISNULL(TMPOIF.rptcol07,'')              --CS01
            ,RptCol03   = ISNULL(TMPOIF.col03,'')                 --CS01
      FROM #TMP_ORD35 TMP
      JOIN ORDERS      OH WITH (NOLOCK) ON (TMP.Orderkey = OH.Orderkey)
      JOIN STORER      ST WITH (NOLOCK) ON (OH.Storerkey = ST.Storerkey)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey) 
                                      --  and OD.sku = TMP.sku
      JOIN SKU S WITH (NOLOCK) ON OD.storerkey = S.storerkey AND OD.sku = S.sku
      LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.listname = 'PRESSSTYLE' And C1.storerkey = OH.Storerkey and C1.code=OD.lottable08
      LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON C2.listname = 'PRESSLOC' And C2.storerkey = OH.Storerkey and C2.code=OD.lottable10
      LEFT JOIN #TempSPLITORDINFO TMPOIF WITH (NOLOCK) ON TMPOIF.Orderkey = OH.Orderkey         --CS01
      GROUP BY   TMPOIF.SeqNo     --CS01
                 ,OH.orderkey
                 ,OH.Storerkey
                 ,OD.OrderLineNumber
                 ,OH.M_Company
                 ,ISNULL(C1.long,'')
                 ,ISNULL(C2.long,'') 
                 ,TMP.SKU
                 ,OD.Lottable08
                 ,OD.Lottable09
                 ,TMP.TotalQty
                 ,TMP.Recgrp
                 ,ISNULL(c_contact1,'')
                -- ,ISNULL(OD.notes,'')                   --CS01
                 ,ISNULL(TMPOIF.col01,'')                 --CS01  
                 ,ISNULL(TMPOIF.rptcol05,'')              --CS01
                 ,ISNULL(TMPOIF.rptcol07,'')              --CS01 
                 ,ISNULL(TMPOIF.col03,'')                 --CS01
      ORDER BY TMPOIF.SeqNo                               --CS01

      
    
      SELECT   SeqNo      
            ,  Orderkey   
            ,  Storerkey 
            ,  OrdLineNumber 
            ,  m_company   
            ,  C1Long     
            ,  C2Long     
            ,  SKU        
            ,  Lottable08        
            ,  Lottable09  
            ,  Qty        
            ,  RecGrp                     
            ,  C_Contact1  
            ,  ODNotes  
            ,  RptCol05             --CS01
            ,  RptCol07             --CS01
            ,  RptCol03             --CS01
      FROM #TMP_HDR35
      ORDER BY SeqNo                    

      
      DROP TABLE #TMP_HDR35
      DROP TABLE #TempSPLITORDINFO        --CS01
      GOTO QUIT_SP


QUIT_SP:  
END       

GO