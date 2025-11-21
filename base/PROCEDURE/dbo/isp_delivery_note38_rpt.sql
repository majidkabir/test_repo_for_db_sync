SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_delivery_note38_rpt                                 */
/* Creation Date: 02-AUG-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-9989 - [CN] Erno Laszlo_AFIONA_Delivery Note            */
/*        :                                                             */
/* Called By: r_dw_delivery_note38_rpt                                  */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/*14-Oct-2019  WLChooi  1.1   WMS-10862 - Add new column (WL01)         */
/*30-Sep-2021  Mingle   1.2   WMS-18050 - Add lottable02 (ML01)         */
/*14-Oct-2021  Mingle   1.2   DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[isp_delivery_note38_rpt]
            @c_OrderKey        NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT
         , @c_ExtOrderkey     NVARCHAR(50)
         , @c_SKU             NVARCHAR(20)
         , @c_Sdescr          NVARCHAR(120)
         , @c_altsku          NVARCHAR(20)
         , @c_sbusr4          NVARCHAR(200)
         , @c_BoxNo           NVARCHAR(10)
         , @n_pqty            INT
         , @c_casecnt         FLOAT
         , @c_FullCtn         INT
         , @n_looseqty        INT
         , @n_Ctn             INT
         , @n_startcnt        INT
         , @n_Packqty         INT
         , @n_cntsku          INT
         , @n_ttlctn          INT
         , @n_ttlqty          INT
         , @n_lastctn         INT
         , @n_lineno          INT
         , @c_Storerkey       NVARCHAR(20)
         , @c_Rpttitle16      NVARCHAR(200)
         , @c_Rpttitle17      NVARCHAR(200)
         , @c_Rpttitle18      NVARCHAR(200)
         , @c_Rpttitle19      NVARCHAR(200)
         , @c_CLRCode         NVARCHAR(50)
         , @c_CLRLONG         NVARCHAR(200)
        
   CREATE Table #TempDELNOTES38rpt(
                 OrderKey           NVARCHAR(10)  NULL 
               , ExternOrderkey     NVARCHAR(50)  NULL 
               , AltSKU             NVARCHAR(20)  NULL
               , OrderDate          DATETIME      NULL
               , PackQty            INT 
               , CASECNT            FLOAT
               , CASEQTY            INT
               , SKU                NVARCHAR(20)  NULL
               , SDESCR             NVARCHAR(120) NULL 
               , Rpttitle16         NVARCHAR(200) NULL
               , Rpttitle17         NVARCHAR(200) NULL
               , Rpttitle18         NVARCHAR(200) NULL
               , Rpttitle19         NVARCHAR(200) NULL
               , looseqty           INT
               , Lottable04         NVARCHAR(10)  NULL
               , Lottable02         NVARCHAR(10)  NULL   --ML01
            )

   --SET @n_StartTCnt = @@TRANCOUNT
   SET @n_startcnt = 1
   SET @n_lastctn = 1
   SET @n_lineno = 1
   SET @c_Rpttitle16 = ''
   SET @c_Rpttitle17 = ''
   SET @c_Rpttitle18 = ''
   SET @c_Rpttitle19 = ''

   SELECT TOP 1 @c_Storerkey = PD.Storerkey
   FROM PICKDETAIL PD WITH (nolock)
   WHERE PD.Orderkey = @c_OrderKey

   SELECT @c_Rpttitle16 = MAX(CASE WHEN C.code='00016' THEN ISNULL(C.long,'') ELSE '' END)
        , @c_Rpttitle17 = MAX(CASE WHEN C.code='00017' THEN ISNULL(C.long,'') ELSE '' END)
        , @c_Rpttitle18 = MAX(CASE WHEN C.code='00018' THEN ISNULL(C.long,'') ELSE '' END)
        , @c_Rpttitle19 = MAX(CASE WHEN C.code='00019' THEN ISNULL(C.long,'') ELSE '' END)
   FROM CODELKUP C WITH (NOLOCK)
   WHERE C.listname = 'ELRPT'
   AND C.Storerkey = @c_Storerkey
   
   INSERT INTO #TempDELNOTES38rpt (OrderKey, ExternOrderkey, SKU, SDESCR, AltSKU, OrderDate, PackQty, CASECNT, CASEQTY,
                                   Rpttitle16, Rpttitle17, Rpttitle18, Rpttitle19, looseqty, Lottable04, Lottable02)  --WL01   --ML01
   SELECT DISTINCT PD.Orderkey,ORD.ExternOrderkey,PD.SKU,S.descr,S.altsku,ORD.OrderDate,SUM(PD.QTY),P.casecnt,
                   (SUM(PD.QTY)/P.casecnt) as caseqty,ISNULL(@c_Rpttitle16,''),
                   ISNULL(@c_Rpttitle17,''),ISNULL(@c_Rpttitle18,''),ISNULL(@c_Rpttitle19,''),(SUM(PD.QTY) % CAST(P.casecnt as int)) as looseqty,
                   CONVERT(NVARCHAR(10), LOTT.Lottable04, 111), LOTT.Lottable02 --WL01   --ML01
   FROM PICKDETAIL PD WITH (NOLOCK)
   JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PD.orderkey
   JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PD.Storerkey AND S.SKU = PD.SKU
   JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.Packkey
   JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.LOT = PD.LOT AND LOTT.SKU = PD.SKU AND LOTT.STORERKEY = PD.STORERKEY   --WL01
   WHERE PD.Storerkey = @c_Storerkey
   AND PD.Orderkey = @c_OrderKey
   GROUP BY PD.Orderkey,ORD.ExternOrderkey,PD.SKU,S.descr,S.altsku,ORD.OrderDate,P.casecnt,CONVERT(NVARCHAR(10), LOTT.Lottable04, 111), LOTT.Lottable02   --ML01
   ORDER BY PD.SKU, CONVERT(NVARCHAR(10), LOTT.Lottable04, 111) --WL01
         
   SELECT * FROM #TempDELNOTES38rpt
   WHERE OrderKey = @c_OrderKey
   ORDER BY SKU 

END -- procedure

GO