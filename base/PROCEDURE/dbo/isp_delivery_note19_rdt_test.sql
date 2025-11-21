SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*************************************************************************/
/* Stored Procedure: isp_Delivery_Note19_RDT                             */
/* Creation Date: 2015-10-30                                             */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: SOS#354882 - JP_H&M_DN Report                                */
/*                                                                       */
/* Called By: r_dw_delivery_note19_rdt                                   */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver   Purposes                                   */
/* 23-Dec-2015  CSCHONG 1.0   Change mapping (CS01)                      */
/* 19-Feb-2016  CSCHONG 1.1   Change mapping (CS02)                      */
/* 11-Apr-2016  CSCHONG 1.2   SOS#368200 (CS03)                          */
/*************************************************************************/
 

CREATE PROC [dbo].[isp_Delivery_Note19_RDT_TEST]
         (  @c_Orderkey    NVARCHAR(10)
         ,  @c_Loadkey     NVARCHAR(10)= ''
         ,  @c_Type        NVARCHAR(1) = ''
         ,  @c_DWCategory  NVARCHAR(1) = 'H'
         ,  @n_RecGroup    INT         = 0
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

         DECLARE @c_A19  NVARCHAR(250)
                ,@c_A20  NVARCHAR(250)
                ,@c_A21  NVARCHAR(250)
                ,@c_A22  NVARCHAR(250)
                ,@c_A23  NVARCHAR(250)
                ,@c_A24  NVARCHAR(250)
                ,@c_B17 NVARCHAR(250)
                ,@c_B18 NVARCHAR(250)
                ,@c_B19 NVARCHAR(250)
                ,@c_B20  NVARCHAR(250)
                ,@c_B21  NVARCHAR(250)
                ,@c_B22  NVARCHAR(250)
                , @c_storerkey NVARCHAR(20)

  
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

   IF @c_DWCategory = 'D'
   BEGIN
      GOTO Detail
   END

   HEADER:

      CREATE TABLE #TMP_ORDH
            (  SeqNo          INT IDENTITY (1,1)
            ,  Orderkey       NVARCHAR(10) DEFAULT ('')
            ,  ORDSKU         NVARCHAR(20)
           -- ,  OrderLinenumber NVARCHAR(5)
            ,  TotalPickQty   INT          DEFAULT (0)
            ,  TotalOrdQty    INT          DEFAULT (0)
            ,  RecGrp         INT
            )

INSERT INTO #TMP_ORDH
            (  Orderkey
            ,  ORDSKU
           -- ,  Orderlinenumber
            ,  TotalPickQty
            ,  TotalOrdQty
            ,  RecGrp
            )
         SELECT PD.Orderkey
              ,PD.SKU
             -- ,OD.Orderlinenumber
               ,SUM(PD.Qty)
               ,SUM(OD.OriginalQty)
               ,(Row_Number() OVER (PARTITION BY PD.Orderkey ORDER BY PD.Orderkey Asc)-1)/@n_NoOfLine
         FROM LOADPLANDETAIL LPD WITH (NOLOCK)
         JOIN PICKDETAIL     PD  WITH (NOLOCK) ON (LPD.Orderkey = PD.Orderkey)
         JOIN ORDERDETAIL OD WITH (NOLOCK)  ON OD.Orderkey = PD.Orderkey AND OD.SKU = PD.SKU
         JOIN LOC            LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)
         WHERE LPD.Loadkey = CASE WHEN ISNULL(@c_Loadkey,'') <> '' THEN  @c_Loadkey  ELSE LPD.Loadkey END
         AND OD.Orderkey = CASE WHEN ISNULL(@c_Orderkey,'') <> '' THEN @c_Orderkey ELSE OD.Orderkey END
         GROUP BY PD.Orderkey,PD.SKU--,OD.Orderlinenumber
         ORDER BY PD.Orderkey

      SELECT @n_CntLine = MAX(RecGrp)
      FROM #TMP_ORDH
      WHERE Orderkey = @c_Orderkey

      CREATE TABLE #TMP_HDR
            (  SeqNo         INT IDENTITY (1,1)
            ,  Orderkey      NVARCHAR(10)
            ,  A1            NVARCHAR(250)
            ,  A2            NVARCHAR(250)
            ,  A3            NVARCHAR(250)
            ,  A4            NVARCHAR(250)
            ,  A6            NVARCHAR(4000)
            ,  A7            NVARCHAR(18)
          --  ,  A8            NVARCHAR(18)
         --   ,  A9            INT
        --    ,  A10           INT
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
         --   ,  B4            VARCHAR(10)
            ,  B9            NVARCHAR(250)
            ,  B10           NVARCHAR(250)
            ,  B1101         NVARCHAR(250)    --CS01
            ,  B1102         NVARCHAR(250)    --CS01
            ,  B1103         NVARCHAR(250)    --CS01
            ,  B1104         NVARCHAR(250)    --CS01
            ,  B1105         NVARCHAR(250)    --CS01
            ,  B1106         NVARCHAR(250)    --CS01
            ,  B1107         NVARCHAR(250)    --CS01
            ,  B1108         NVARCHAR(250)    --CS01
            ,  B1109         NVARCHAR(250)    --CS01
            ,  B1110         NVARCHAR(250)    --CS01
            ,  RecGroup      INT
            ,  PNotes        NVARCHAR(250)
            ,  OrdGrp        INT
            ,  A25           NVARCHAR(50)		--(CS02)
            ,  A26           NVARCHAR(50)		--(CS02)
            ,  A27           NVARCHAR(50)		--(CS02)
            ,  A28           NVARCHAR(50)		--(CS02)
             ,  C1           NVARCHAR(50)		--(CS02)
             ,  C2           NVARCHAR(50)		--(CS02)
             ,  C3           NVARCHAR(50)		--(CS02)
            )

	IF @c_Loadkey <> ''
	BEGIN
		  INSERT INTO #TMP_HDR
				(  Orderkey
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
			 --   ,  B4
				,  B9
				,  B10
				,  B1101             --CS01
				,  B1102             --CS01
				,  B1103             --CS01
				,  B1104             --CS01
				,  B1105             --CS01
				,  B1106            --CS01
				,  B1107             --CS01
				,  B1108             --CS01
				,  B1109             --CS01
				,  B1110             --CS01
				,  RecGroup
				,  PNotes
				,  OrdGrp
				,  A25           --(CS02)
				,  A26           --(CS02)
				,  A27           --(CS02)
				,  A28           --(CS02)
				, C1
				, C2
				, C3
				)
		  SELECT DISTINCT
			   --  TMP.SeqNo
				OH.Orderkey
				,A1         = OH.C_Company + ISNULL(MAX(CASE WHEN CL.Code = 'A1' THEN RTRIM(CL.Description) ELSE '' END),'')
				,A2         = ISNULL(MAX(CASE WHEN CL.Code = 'A2' THEN RTRIM(CL.Description) ELSE '' END),'')
				,A3         = ISNULL(MAX(CASE WHEN CL.Code = 'A3' THEN RTRIM(CL.Description) ELSE '' END),'')
				,A4         = ISNULL(MAX(CASE WHEN CL.Code = 'A4' THEN RTRIM(CL.Description) ELSE '' END),'')
				,A6         = ISNULL(RTRIM(OH.Notes),'') + ','  + ISNULL(RTRIM(OH.Notes2),'')
				,A7         = ISNULL(RTRIM(OH.UserDefine06),'')
			 --   ,A8         = ISNULL(RTRIM(Substring(OD.SKU,1,7)),'')  + '-' +  ISNULL(RTRIM(Substring(OD.SKU,8,3)),'')
			 --                 + '-' +  ISNULL(RTRIM(Substring(OD.SKU,11,3)),'')
			  --   ,A9         = SUM(TMP.TotalOrdQty)
			  --  ,A10        = SUM(TMP.TotalPickQty)
				,A11        = ISNULL(MAX(CASE WHEN CL.Code = 'A11' THEN RTRIM(CL.Description) ELSE '' END),'')
				,A12        = ISNULL(MAX(CASE WHEN CL.Code = 'A12' THEN RTRIM(CL.Description) ELSE '' END),'')
				,A13        = ISNULL(MAX(CASE WHEN CL.Code = 'A13' THEN RTRIM(CL.Description) ELSE '' END),'')
				,A14        = ISNULL(MAX(CASE WHEN CL.Code = 'A14' THEN RTRIM(CL.Description) ELSE '' END),'')
				,A15        = ISNULL(RTRIM(OH.BuyerPO),'')
				,A16        = ISNULL(RTRIM(CONVERT(NVARCHAR(10),OH.OrderDate,112)),'')
				,A17        = ISNULL(RTRIM(MAX(OH.Notes2)),'')
				,A18_1      = (ISNULL(RTRIM(OH.C_Company),'') + ISNULL(RTRIM(ST.B_Contact2),'') )
				,A18_2      = ISNULL(RTRIM(OH.C_Zip),'')
				,A18_3      = ISNULL(RTRIM(OH.C_State),'')
				,A18_4      = ISNULL(RTRIM(OH.C_City),'')
				,A18_5      = ISNULL(RTRIM(C_Address1),'')                                                                 --(CS02)
				,A18_6      = ISNULL(RTRIM(C_Address2),'') + ISNULL(RTRIM(C_Address3),'') + ISNULL(RTRIM(C_Address4),'')
				,B1        = ISNULL(MAX(CASE WHEN CL.Code = 'B1' THEN RTRIM(CL.Description) ELSE '' END),'')
				,B2        = ISNULL(MAX(CASE WHEN CL.Code = 'B2' THEN RTRIM(CL.Description) ELSE '' END),'')
			   -- ,B4        = CASE WHEN SUM(TMP.TotalPickQty) = 0 THEN 'X' ELSE '______' END
				,B9        = ISNULL(MAX(CASE WHEN CL.Code = 'B9' THEN RTRIM(CL.Description) ELSE '' END),'')
				,B10        = ISNULL(MAX(CASE WHEN CL.Code ='B10' THEN RTRIM(CL.Description) ELSE '' END),'')
				,B1101        = ISNULL(MAX(CASE WHEN CL.Code ='B1101' THEN RTRIM(CL.Description) ELSE '' END),'')             --CS01
				,B1102        = ISNULL(MAX(CASE WHEN CL.Code ='B1102' THEN RTRIM(CL.Description) ELSE '' END),'')             --CS01
				,B1103        = ISNULL(MAX(CASE WHEN CL.Code ='B1103' THEN RTRIM(CL.Description) ELSE '' END),'')             --CS01
				,B1104        = ISNULL(MAX(CASE WHEN CL.Code ='B1104' THEN RTRIM(CL.Description) ELSE '' END),'')             --CS01
				,B1105        = ISNULL(MAX(CASE WHEN CL.Code ='B1105' THEN RTRIM(CL.Description) ELSE '' END),'')             --CS01
				,B1106        = ISNULL(MAX(CASE WHEN CL.Code ='B1106' THEN RTRIM(CL.Description) ELSE '' END),'')             --CS01
				,B1107        = ISNULL(MAX(CASE WHEN CL.Code ='B1107' THEN RTRIM(CL.Description) ELSE '' END),'')             --CS01
				,B1108        = ISNULL(MAX(CASE WHEN CL.Code ='B1108' THEN RTRIM(CL.Description) ELSE '' END),'')             --CS01
				,B1109        = ISNULL(MAX(CASE WHEN CL.Code ='B1109' THEN RTRIM(CL.Description) ELSE '' END),'')             --CS01
				,B1110        = ISNULL(MAX(CASE WHEN CL.Code ='B1110' THEN RTRIM(CL.Description) ELSE '' END),'')             --CS01
				,RecGroup   =(Row_Number() OVER (PARTITION BY OH.Orderkey ORDER BY OH.Orderkey,  MIN(CONVERT(INT,OD.ExternLineNo)) Asc)-1)/@n_NoOfLine
				,PNotes     = ISNULL(PD.notes,'')
				,OrdGrp     = 1
				--,A19        = ISNULL(MAX(CASE WHEN CL.Code = 'A19' THEN RTRIM(CL.Description) ELSE '' END),'')
				--,A20        = ISNULL(MAX(CASE WHEN CL.Code = 'A20' THEN RTRIM(CL.Description) ELSE '' END),'')
				--,A21        = ISNULL(MAX(CASE WHEN CL.Code = 'A21' THEN RTRIM(CL.Description) ELSE '' END),'')
				--,A22        = ISNULL(MAX(CASE WHEN CL.Code = 'A22' THEN RTRIM(CL.Description) ELSE '' END),'')
				--,A23        = ISNULL(MAX(CASE WHEN CL.Code = 'A23' THEN RTRIM(CL.Description) ELSE '' END),'')
				--,A24        = ISNULL(MAX(CASE WHEN CL.Code = 'A24' THEN RTRIM(CL.Description) ELSE '' END),'')
				,A25        = ISNULL(MAX(CASE WHEN CL.Code = 'A25' THEN RTRIM(CL.Description) ELSE '' END),'')
				,A26        = ISNULL(MAX(CASE WHEN CL.Code = 'A26' THEN RTRIM(CL.Description) ELSE '' END),'')
				,A27        = ISNULL(MAX(CASE WHEN CL.Code = 'A27' THEN RTRIM(CL.Description) ELSE '' END),'')
				,A28        = ISNULL(MAX(CASE WHEN CL.Code = 'A28' THEN RTRIM(CL.Description) ELSE '' END),'')
				--,B17        = ISNULL(MAX(CASE WHEN CL.Code = 'B17' THEN RTRIM(CL.Description) ELSE '' END),'')
				--,B18        = ISNULL(MAX(CASE WHEN CL.Code = 'B18' THEN RTRIM(CL.Description) ELSE '' END),'')
				--,B19        = ISNULL(MAX(CASE WHEN CL.Code = 'B19' THEN RTRIM(CL.Description) ELSE '' END),'')
				--,B20        = ISNULL(MAX(CASE WHEN CL.Code = 'B20' THEN RTRIM(CL.Description) ELSE '' END),'')
				--,B21       = ISNULL(MAX(CASE WHEN CL.Code = 'B21' THEN RTRIM(CL.Description) ELSE '' END),'')
				--,B22       = ISNULL(MAX(CASE WHEN CL.Code = 'B22' THEN RTRIM(CL.Description) ELSE '' END),'')
				,C1        = ISNULL(MAX(CASE WHEN CL.Code = 'C1' THEN RTRIM(CL.Description) ELSE '' END),'')
				,C2        = ISNULL(MAX(CASE WHEN CL.Code = 'C2' THEN RTRIM(CL.Description) ELSE '' END),'')
				,C3        = ISNULL(MAX(CASE WHEN CL.Code = 'C3' THEN RTRIM(CL.Description) ELSE '' END),'')
		  -- FROM #TMP_ORD TMP
		  FROM ORDERS      OH WITH (NOLOCK) --ON (TMP.Orderkey = OH.Orderkey)
		  JOIN STORER      ST WITH (NOLOCK) ON (OH.Storerkey = ST.Storerkey)
		  JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
		  LEFT JOIN PICKDETAIL  PD  WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey AND OD.sku = PD.sku
														 AND OD.Orderlinenumber = PD.Orderlinenumber)
		  LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'HMDN' AND CL.Storerkey = OH.Storerkey)
		  WHERE OH.Loadkey = @c_Loadkey
		  GROUP BY  OH.Orderkey
				,  OH.Storerkey
				,  OH.C_Company
				,  ISNULL(RTRIM(OH.Notes),'')
				,  ISNULL(RTRIM(OH.Notes2),'')
				,  ISNULL(RTRIM(OH.UserDefine06),'')
				,  ISNULL(RTRIM(Substring(OD.SKU,1,7)),'')
				,  ISNULL(RTRIM(Substring(OD.SKU,8,3)),'')
				,  ISNULL(RTRIM(Substring(OD.SKU,11,3)),'')
				,  ISNULL(RTRIM(OH.BuyerPO),'')
				,  ISNULL(RTRIM(CONVERT(NVARCHAR(10),OH.OrderDate,112)),'')
				,  ISNULL(RTRIM(OH.C_Company),'')
				,  ISNULL(RTRIM(ST.B_Contact2),'')
				,  ISNULL(RTRIM(OH.C_state),'')
				,  ISNULL(RTRIM(OH.C_Zip),'')
				,  ISNULL(RTRIM(OH.C_City),'')
				,  ISNULL(RTRIM(C_Address1),'')                             --(CS02)
				,  ISNULL(RTRIM(C_Address2),'')
				,  ISNULL(RTRIM(C_Address3),'')
				,  ISNULL(RTRIM(C_Address4),'')
				,  ISNULL(PD.notes,'')
			  ORDER BY ISNULL(PD.notes,''),OH.Orderkey
		END
		ELSE
		BEGIN
			IF @c_Orderkey <> ''
			BEGIN
				INSERT INTO #TMP_HDR
					(  Orderkey
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
				 --   ,  B4
					,  B9
					,  B10
					,  B1101             --CS01
					,  B1102             --CS01
					,  B1103             --CS01
					,  B1104             --CS01
					,  B1105             --CS01
					,  B1106            --CS01
					,  B1107             --CS01
					,  B1108             --CS01
					,  B1109             --CS01
					,  B1110             --CS01
					,  RecGroup
					,  PNotes
					,  OrdGrp
					,  A25           --(CS02)
					,  A26           --(CS02)
					,  A27           --(CS02)
					,  A28           --(CS02)
					, C1
					, C2
					, C3
					)
			  SELECT DISTINCT
				   --  TMP.SeqNo
					OH.Orderkey
					,A1         = OH.C_Company + ISNULL(MAX(CASE WHEN CL.Code = 'A1' THEN RTRIM(CL.Description) ELSE '' END),'')
					,A2         = ISNULL(MAX(CASE WHEN CL.Code = 'A2' THEN RTRIM(CL.Description) ELSE '' END),'')
					,A3         = ISNULL(MAX(CASE WHEN CL.Code = 'A3' THEN RTRIM(CL.Description) ELSE '' END),'')
					,A4         = ISNULL(MAX(CASE WHEN CL.Code = 'A4' THEN RTRIM(CL.Description) ELSE '' END),'')
					,A6         = ISNULL(RTRIM(OH.Notes),'') + ','  + ISNULL(RTRIM(OH.Notes2),'')
					,A7         = ISNULL(RTRIM(OH.UserDefine06),'')
					,A11        = ISNULL(MAX(CASE WHEN CL.Code = 'A11' THEN RTRIM(CL.Description) ELSE '' END),'')
					,A12        = ISNULL(MAX(CASE WHEN CL.Code = 'A12' THEN RTRIM(CL.Description) ELSE '' END),'')
					,A13        = ISNULL(MAX(CASE WHEN CL.Code = 'A13' THEN RTRIM(CL.Description) ELSE '' END),'')
					,A14        = ISNULL(MAX(CASE WHEN CL.Code = 'A14' THEN RTRIM(CL.Description) ELSE '' END),'')
					,A15        = ISNULL(RTRIM(OH.BuyerPO),'')
					,A16        = ISNULL(RTRIM(CONVERT(NVARCHAR(10),OH.OrderDate,112)),'')
					,A17        = ISNULL(RTRIM(MAX(OH.Notes2)),'')
					,A18_1      = (ISNULL(RTRIM(OH.C_Company),'') + ISNULL(RTRIM(ST.B_Contact2),'') )
					,A18_2      = ISNULL(RTRIM(OH.C_Zip),'')
					,A18_3      = ISNULL(RTRIM(OH.C_State),'')
					,A18_4      = ISNULL(RTRIM(OH.C_City),'')
					,A18_5      = ISNULL(RTRIM(C_Address1),'')                                                                 --(CS02)
					,A18_6      = ISNULL(RTRIM(C_Address2),'') + ISNULL(RTRIM(C_Address3),'') + ISNULL(RTRIM(C_Address4),'')
					,B1        = ISNULL(MAX(CASE WHEN CL.Code = 'B1' THEN RTRIM(CL.Description) ELSE '' END),'')
					,B2        = ISNULL(MAX(CASE WHEN CL.Code = 'B2' THEN RTRIM(CL.Description) ELSE '' END),'')
				   -- ,B4        = CASE WHEN SUM(TMP.TotalPickQty) = 0 THEN 'X' ELSE '______' END
					,B9        = ISNULL(MAX(CASE WHEN CL.Code = 'B9' THEN RTRIM(CL.Description) ELSE '' END),'')
					,B10        = ISNULL(MAX(CASE WHEN CL.Code ='B10' THEN RTRIM(CL.Description) ELSE '' END),'')
					,B1101        = ISNULL(MAX(CASE WHEN CL.Code ='B1101' THEN RTRIM(CL.Description) ELSE '' END),'')             --CS01
					,B1102        = ISNULL(MAX(CASE WHEN CL.Code ='B1102' THEN RTRIM(CL.Description) ELSE '' END),'')             --CS01
					,B1103        = ISNULL(MAX(CASE WHEN CL.Code ='B1103' THEN RTRIM(CL.Description) ELSE '' END),'')             --CS01
					,B1104        = ISNULL(MAX(CASE WHEN CL.Code ='B1104' THEN RTRIM(CL.Description) ELSE '' END),'')             --CS01
					,B1105        = ISNULL(MAX(CASE WHEN CL.Code ='B1105' THEN RTRIM(CL.Description) ELSE '' END),'')             --CS01
					,B1106        = ISNULL(MAX(CASE WHEN CL.Code ='B1106' THEN RTRIM(CL.Description) ELSE '' END),'')             --CS01
					,B1107        = ISNULL(MAX(CASE WHEN CL.Code ='B1107' THEN RTRIM(CL.Description) ELSE '' END),'')             --CS01
					,B1108        = ISNULL(MAX(CASE WHEN CL.Code ='B1108' THEN RTRIM(CL.Description) ELSE '' END),'')             --CS01
					,B1109        = ISNULL(MAX(CASE WHEN CL.Code ='B1109' THEN RTRIM(CL.Description) ELSE '' END),'')             --CS01
					,B1110        = ISNULL(MAX(CASE WHEN CL.Code ='B1110' THEN RTRIM(CL.Description) ELSE '' END),'')             --CS01
					,RecGroup   =(Row_Number() OVER (PARTITION BY OH.Orderkey ORDER BY OH.Orderkey,  MIN(CONVERT(INT,OD.ExternLineNo)) Asc)-1)/@n_NoOfLine
					,PNotes     = ISNULL(PD.notes,'')
					,OrdGrp     = 1
					,A25        = ISNULL(MAX(CASE WHEN CL.Code = 'A25' THEN RTRIM(CL.Description) ELSE '' END),'')
					,A26        = ISNULL(MAX(CASE WHEN CL.Code = 'A26' THEN RTRIM(CL.Description) ELSE '' END),'')
					,A27        = ISNULL(MAX(CASE WHEN CL.Code = 'A27' THEN RTRIM(CL.Description) ELSE '' END),'')
					,A28        = ISNULL(MAX(CASE WHEN CL.Code = 'A28' THEN RTRIM(CL.Description) ELSE '' END),'')
					,C1        = ISNULL(MAX(CASE WHEN CL.Code = 'C1' THEN RTRIM(CL.Description) ELSE '' END),'')
					,C2        = ISNULL(MAX(CASE WHEN CL.Code = 'C2' THEN RTRIM(CL.Description) ELSE '' END),'')
					,C3        = ISNULL(MAX(CASE WHEN CL.Code = 'C3' THEN RTRIM(CL.Description) ELSE '' END),'')
			  -- FROM #TMP_ORD TMP
			  FROM ORDERS      OH WITH (NOLOCK) --ON (TMP.Orderkey = OH.Orderkey)
			  JOIN STORER      ST WITH (NOLOCK) ON (OH.Storerkey = ST.Storerkey)
			  JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
			  LEFT JOIN PICKDETAIL  PD  WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey AND OD.sku = PD.sku
															 AND OD.Orderlinenumber = PD.Orderlinenumber)
			  LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'HMDN' AND CL.Storerkey = OH.Storerkey)
			  WHERE  OD.Orderkey = @c_Orderkey
			  GROUP BY  OH.Orderkey
					,  OH.Storerkey
					,  OH.C_Company
					,  ISNULL(RTRIM(OH.Notes),'')
					,  ISNULL(RTRIM(OH.Notes2),'')
					,  ISNULL(RTRIM(OH.UserDefine06),'')
					,  ISNULL(RTRIM(Substring(OD.SKU,1,7)),'')
					,  ISNULL(RTRIM(Substring(OD.SKU,8,3)),'')
					,  ISNULL(RTRIM(Substring(OD.SKU,11,3)),'')
					,  ISNULL(RTRIM(OH.BuyerPO),'')
					,  ISNULL(RTRIM(CONVERT(NVARCHAR(10),OH.OrderDate,112)),'')
					,  ISNULL(RTRIM(OH.C_Company),'')
					,  ISNULL(RTRIM(ST.B_Contact2),'')
					,  ISNULL(RTRIM(OH.C_state),'')
					,  ISNULL(RTRIM(OH.C_Zip),'')
					,  ISNULL(RTRIM(OH.C_City),'')
					,  ISNULL(RTRIM(C_Address1),'')                             --(CS02)
					,  ISNULL(RTRIM(C_Address2),'')
					,  ISNULL(RTRIM(C_Address3),'')
					,  ISNULL(RTRIM(C_Address4),'')
					,  ISNULL(PD.notes,'')
				  ORDER BY ISNULL(PD.notes,''),OH.Orderkey

				END
		END

IF @b_debug = 1
BEGIN
   INSERT INTO TRACEINFO (TraceName, timeIn, Step1, Step2, step3, step4, step5)
   VALUES ('isp_Delivery_Note19_RDT', getdate(), @c_DWCategory, @c_Loadkey, @c_orderkey, '', suser_name())
END


      SELECT @n_CntTTLLine = MAX(OrdGrp)
      FROM #TMP_HDR
      WHERE Orderkey = @c_Orderkey

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
            --,  A19           --(CS02)
            --,  A20           --(CS02)
            --,  A21           --(CS02)
            --,  A22           --(CS02)
            --,  A23           --(CS02)
            --,  A24          --(CS02)
            ,  A25           --(CS02)
            ,  A26           --(CS02)
            ,  A27           --(CS02)
            ,  A28           --(CS02)
            --,  B17           --(CS02)
            --,  B18           --(CS02)
            --,  B19           --(CS02)
            --,  B20           --(CS02)
            --,  B21           --(CS02)
            --,  B22           --(CS02)
            , C1
            , C2
            , C3
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
         --   ,  B4
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
            --,  A19           --(CS02)
            --,  A20           --(CS02)
            --,  A21           --(CS02)
            --,  A22           --(CS02)
            --,  A23           --(CS02)
            --,  A24          --(CS02)
            ,  A25           --(CS02)
            ,  A26           --(CS02)
            ,  A27           --(CS02)
            ,  A28           --(CS02)
            --,  B17           --(CS02)
            --,  B18           --(CS02)
            --,  B19           --(CS02)
            --,  B20           --(CS02)
            --,  B21           --(CS02)
            --,  B22           --(CS02)
            , C1
            , C2
            , C3
  FROM #TMP_HDR
 WHERE seqno = 1

 SET @n_RecNo = @n_RecNo + 1
 SET @n_CntLine = @n_CntLine -1
 --SET @n_NoOfPage = 1
END

      DECLARE CUR_PageLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Orderkey--, RecGroup
      FROM   #TMP_HDR
      ORDER BY Orderkey--,RecGroup


      OPEN CUR_PageLoop

      FETCH NEXT FROM CUR_PageLoop INTO @c_GetOrderkey --,@c_getRecGrp

      WHILE @@FETCH_STATUS <> -1
      BEGIN
      SET @n_NoOfPage = 1

     SELECT @n_cntPNote = Count (DISTINCT pnotes)
            ,@n_seqno   = MIN (seqno)
     FROM #TMP_HDR
     WHERE orderkey=@c_GetOrderkey

      SELECT @n_NoOfPage = COUNT(DISTINCT caseid)
      FROM pickdetail (NOLOCK)
      WHERE orderkey=@c_GetOrderkey
      --AND ISNULL(caseid,'') <> ''
     --GROUP BY caseid

      IF @n_cntPNote > 1
      BEGIN

        DELETE #TMP_HDR
        WHERE orderkey=@c_GetOrderkey
        AND seqno=@n_seqno


      END

       SET @n_totalPage = @n_NoOfPage
--
--    SELECT @n_CntGrp = MAX()
--       FROM #TMP_HDR
--       WHERE Orderkey = @c_GetOrderkey

  -- IF @n_totalPage <> @n_CntGrp
  -- BEGIN
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
         --   ,  B4
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
            --,  A19           --(CS02)
            --,  A20           --(CS02)
            --,  A21           --(CS02)
            --,  A22           --(CS02)
            --,  A23           --(CS02)
            --,  A24          --(CS02)
            ,  A25           --(CS02)
            ,  A26           --(CS02)
            ,  A27           --(CS02)
            ,  A28           --(CS02)
            --,  B17           --(CS02)
            --,  B18           --(CS02)
            --,  B19           --(CS02)
            --,  B20           --(CS02)
            --,  B21           --(CS02)
            --,  B22           --(CS02)
            , C1
            , C2
            , C3
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
         --   ,  B4
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
            --,  A19           --(CS02)
            --,  A20           --(CS02)
            --,  A21           --(CS02)
            --,  A22           --(CS02)
            --,  A23           --(CS02)
            --,  A24          --(CS02)
            ,  A25           --(CS02)
            ,  A26           --(CS02)
            ,  A27           --(CS02)
            ,  A28           --(CS02)
            --,  B17           --(CS02)
            --,  B18           --(CS02)
            --,  B19           --(CS02)
            --,  B20           --(CS02)
            --,  B21           --(CS02)
            --,  B22           --(CS02)
            , C1
            , C2
            , C3
            FROM #TMP_HDR
            WHERE ORDERKEY = @c_GetOrderkey
            --AND RecGroup = @c_getRecGrp
            AND Ordgrp = 1

       SET @n_NoOfPage = @n_NoOfPage - 1
       SET @n_CurrGrp = @n_CurrGrp + 1

       IF @n_NoOfPage = 1
        BREAK;
 END
  --  END

       FETCH NEXT FROM CUR_PageLoop INTO @c_GetOrderkey --,@c_getRecGrp
   END

     CLOSE CUR_PageLoop

      SELECT * FROM #TMP_HDR
      ORDER BY pnotes,orderkey,OrdGrp

     -- DROP TABLE #TMP_ORD
     -- DROP TABLE #TMP_HDR
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
            ,  A19           NVARCHAR(50)   NULL  --(CS02)
            ,  A20           NVARCHAR(50)   NULL  --(CS02)
            ,  A21           NVARCHAR(50)	  NULL	--(CS02)
            ,  A22           NVARCHAR(50)	  NULL	--(CS02)
            ,  A23           NVARCHAR(50)	  NULL	--(CS02)
            ,  A24           NVARCHAR(50)	  NULL	--(CS02)
            ,  B17           NVARCHAR(50)	  NULL	--(CS02)
            ,  B18           NVARCHAR(50)	  NULL	--(CS02)
            ,  B19           NVARCHAR(50)	  NULL	--(CS02)
            ,  B20           NVARCHAR(50)	  NULL	--(CS02)
            ,  B21           NVARCHAR(50)	  NULL	--(CS02)
            ,  B22           NVARCHAR(50)	  NULL	--(CS02)
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
            SET @c_storerkey = ''

            SELECT TOP 1 @c_storerkey = Storerkey
            FROM ORDERS (NOLOCK)
            WHERE Orderkey = @c_Orderkey

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

	
		  
		INSERT INTO #TMP_ORDDET
            (  serialno
            ,  Orderkey
            ,  SKU
            ,  ODNotes
            ,  ODUserDef06
            ,  TotalPickQty
            ,  TotalOrdQty
            ,  RecGroup
            ,  A19           --(CS02)
            ,  A20           --(CS02)
            ,  A21           --(CS02)
            ,  A22           --(CS02)
            ,  A23           --(CS02)
     ,  A24      --(CS02)
            ,  B17           --(CS02)
            ,  B18           --(CS02)
            ,  B19           --(CS02)
            ,  B20           --(CS02)
            ,  B21           --(CS02)
            ,  B22           --(CS02)
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
               ,(Row_Number() OVER (PARTITION BY OD.Orderkey ORDER BY OD.Orderkey Asc)-1)/@n_NoOfLine
            --,A19        = ISNULL(MAX(CASE WHEN CL.Code = 'A19' THEN RTRIM(CL.Description) ELSE '' END),'')
            --,A20        = ISNULL(MAX(CASE WHEN CL.Code = 'A20' THEN RTRIM(CL.Description) ELSE '' END),'')
            --,A21        = ISNULL(MAX(CASE WHEN CL.Code = 'A21' THEN RTRIM(CL.Description) ELSE '' END),'')
            --,A22        = ISNULL(MAX(CASE WHEN CL.Code = 'A22' THEN RTRIM(CL.Description) ELSE '' END),'')
            --,A23        = ISNULL(MAX(CASE WHEN CL.Code = 'A23' THEN RTRIM(CL.Description) ELSE '' END),'')
            --,A24        = ISNULL(MAX(CASE WHEN CL.Code = 'A24' THEN RTRIM(CL.Description) ELSE '' END),'')
            --,B17        = ISNULL(MAX(CASE WHEN CL.Code = 'B17' THEN RTRIM(CL.Description) ELSE '' END),'')
            --,B18        = ISNULL(MAX(CASE WHEN CL.Code = 'B18' THEN RTRIM(CL.Description) ELSE '' END),'')
            --,B19        = ISNULL(MAX(CASE WHEN CL.Code = 'B19' THEN RTRIM(CL.Description) ELSE '' END),'')
            --,B20        = ISNULL(MAX(CASE WHEN CL.Code = 'B20' THEN RTRIM(CL.Description) ELSE '' END),'')
            --,B21       = ISNULL(MAX(CASE WHEN CL.Code = 'B21' THEN RTRIM(CL.Description) ELSE '' END),'')
            --,B22       = ISNULL(MAX(CASE WHEN CL.Code = 'B22' THEN RTRIM(CL.Description) ELSE '' END),'')
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
         FROM LOADPLANDETAIL LPD WITH (NOLOCK)
         JOIN ORDERDETAIL OD WITH (NOLOCK)  ON OD.Orderkey = LPD.Orderkey
         LEFT OUTER JOIN PICKDETAIL  PD  WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey AND OD.sku = PD.sku
                                                      AND OD.Orderlinenumber = PD.Orderlinenumber)
         LEFT OUTER JOIN LOC   LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)
         --LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'HMDN' AND CL.Storerkey = OD.Storerkey)
         --CROSS APPLY (select DISTINCT A19,A20,A21,,A22 ,A23,A24,B17,B18,B19,B20,B21,B22
         --             FROM CODELKUP CL1 WITH (NOLOCK) WHERE CL1.Storerkey=OD.Storerkey
         --                      ) AS CL
         WHERE OD.Orderkey = @c_Orderkey
         GROUP BY OD.Orderkey,OD.SKU,ISNULL(RTRIM(OD.UserDefine06),''),OD.Notes,OD.Notes2
         ORDER BY OD.Orderkey


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

  DROP TABLE #TMP_ORD
  DROP TABLE #TMP_HDR
  DROP TABLE #TMP_ORDH

   QUIT_SP:
END

GO