SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_delivery_note37_rpt                                 */
/* Creation Date: 25-JUL-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-9964 - [CN] Erno Laszlo_Delivery Note                   */
/*        :                                                             */
/* Called By: r_dw_delivery_note37_rpt                                  */
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
CREATE PROC [dbo].[isp_delivery_note37_rpt]
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
         , @c_Rpttitle01      NVARCHAR(200)
         , @c_Rpttitle02      NVARCHAR(200)
         , @c_Rpttitle03      NVARCHAR(200)
         , @c_Rpttitle04      NVARCHAR(200)
         , @c_Rpttitle05      NVARCHAR(200)
         , @c_Rpttitle13      NVARCHAR(200)
         , @c_Rpttitle14      NVARCHAR(200)
         , @c_Rpttitle15      NVARCHAR(200)
         , @c_CLRCode         NVARCHAR(50)
         , @c_CLRLONG         NVARCHAR(200)
       
       
   CREATE Table #TempDELNOTES37rpt(
                 OrderKey           NVARCHAR(10) NULL 
               , ExternOrderkey     NVARCHAR(50) NULL 
               , AltSKU             NVARCHAR(20) NULL
               , SBUSR4             NVARCHAR(200) NULL
               , PackQty            INT 
               , TTLPQTY            INT
               , TTLCTN             INT
               , CTNSKU             INT
               , BoxNo              NVARCHAR(10) NULL
               , Rpttitle01         NVARCHAR(200) NULL 
               , Rpttitle02         NVARCHAR(200) NULL
               , SKU                NVARCHAR(20) NULL
               , SDESCR             NVARCHAR(120) NULL 
               , Rpttitle03         NVARCHAR(200) NULL
               , Rpttitle04         NVARCHAR(200) NULL
               , Rpttitle05         NVARCHAR(200) NULL
               , Rpttitle13         NVARCHAR(200) NULL
               , Rpttitle14         NVARCHAR(200) NULL
               , Rpttitle15         NVARCHAR(200) NULL
            )

   --SET @n_StartTCnt = @@TRANCOUNT
   SET @n_startcnt = 1
   SET @n_lastctn = 1
   SET @n_lineno = 1
   SET @c_Rpttitle01 = ''
   SET @c_Rpttitle02 = ''
   SET @c_Rpttitle03 = ''
   SET @c_Rpttitle04 = ''
   SET @c_Rpttitle05 = ''
   SET @c_Rpttitle13 = ''
   SET @c_Rpttitle14 = ''
   SET @c_Rpttitle15 = ''

   SELECT TOP 1 @c_Storerkey = PD.Storerkey
   FROM PICKDETAIL PD WITH (nolock)
   WHERE PD.Orderkey = @c_OrderKey


   SELECT @c_Rpttitle01 = MAX(CASE WHEN C.code='00001' THEN ISNULL(C.long,'') ELSE '' END)
        , @c_Rpttitle02 = MAX(CASE WHEN C.code='00002' THEN ISNULL(C.long,'') ELSE '' END)
        , @c_Rpttitle03 = MAX(CASE WHEN C.code='00003' THEN ISNULL(C.long,'') ELSE '' END)
        , @c_Rpttitle04 = MAX(CASE WHEN C.code='00004' THEN ISNULL(C.long,'') ELSE '' END)
        , @c_Rpttitle05 = MAX(CASE WHEN C.code='00005' THEN ISNULL(C.long,'') ELSE '' END)
        , @c_Rpttitle13 = MAX(CASE WHEN C.code='00013' THEN ISNULL(C.long,'') ELSE '' END)
        , @c_Rpttitle14 = MAX(CASE WHEN C.code='00014' THEN ISNULL(C.long,'') ELSE '' END)
        , @c_Rpttitle15 = MAX(CASE WHEN C.code='00015' THEN ISNULL(C.long,'') ELSE '' END)
   FROM CODELKUP C WITH (NOLOCK)
   WHERE C.listname = 'ELRPT'
   AND C.Storerkey = @c_Storerkey

   --DECLARE CUR_RPTTITLE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   --select DISTINCT C.code,c.long
   --FROM CODELKUP C WITH (NOLOCK)
   --WHERE C.listname = 'ELRPT'
   --AND C.Storerkey = @c_Storerkey

   --  OPEN CUR_RPTTITLE   
     
   --FETCH NEXT FROM CUR_RPTTITLE INTO @c_CLRCode,@c_CLRLong
     
   --WHILE @@FETCH_STATUS <> -1  
   --BEGIN 

   --IF @c_CLRCode = '00001' 
   --BEGIN
   --  SET @c_Rpttitle01 = @c_CLRLong 
   --END
   --ELSE IF @c_CLRCode = '00002' 
   --BEGIN
   --  SET @c_Rpttitle02 = @c_CLRLong 
   --END
   --ELSE IF @c_CLRCode = '00003' 
   --BEGIN
   --  SET @c_Rpttitle03 = @c_CLRLong 
   --END
   --ELSE IF @c_CLRCode = '00004' 
   --BEGIN
   --  SET @c_Rpttitle04 = @c_CLRLong 
   --END
   --ELSE IF @c_CLRCode = '00005' 
   --BEGIN
   --  SET @c_Rpttitle05 = @c_CLRLong 
   --END
   --ELSE IF @c_CLRCode = '00013' 
   --BEGIN
   --  SET @c_Rpttitle13 = @c_CLRLong 
   --END
   --ELSE IF @c_CLRCode = '00014' 
   --BEGIN
   --  SET @c_Rpttitle14 = @c_CLRLong 
   --END
   --ELSE IF @c_CLRCode = '00015' 
   --BEGIN
   --  SET @c_Rpttitle15 = @c_CLRLong 
   --END

   --FETCH NEXT FROM CUR_RPTTITLE INTO @c_CLRCode,@c_CLRLong
   --END 

   SET @n_ttlqty = 1
   SET @n_cntsku = 1

   SELECT @n_ttlqty = SUM(PD.qty)
   FROM PICKDETAIL PD WITH (NOLOCK)
   WHERE PD.Storerkey = @c_Storerkey
   AND PD.OrderKey = @c_OrderKey

   SELECT @n_cntsku = COUNT(DISTINCT PD.SKU)
    FROM PICKDETAIL PD WITH (NOLOCK)
   WHERE PD.Storerkey = @c_Storerkey
   AND PD.OrderKey = @c_OrderKey

   --select DISTINCT ORD.ExternOrderkey,PD.SKU,S.descr,S.altsku,S.busr4,PD.QTY,P.casecnt,FLOOR(PD.qty/P.casecnt) as ctn
   --,(PD.QTY%cast(P.casecnt as int)) as looseqty
   --FROM PICKDETAIL PD WITH (NOLOCK)
   --JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PD.orderkey
   --JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PD.Storerkey AND S.SKU = PD.SKU
   --JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.Packkey
   --WHERE PD.Storerkey = @c_Storerkey
   --AND PD.Orderkey = @c_OrderKey
   --ORDER BY PD.SKU
   
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   select DISTINCT ORD.ExternOrderkey,PD.SKU,S.descr,S.altsku,S.busr4,SUM(PD.QTY),P.casecnt,FLOOR(SUM(PD.qty)/P.casecnt) as ctn
   ,(SUM(PD.QTY)%cast(P.casecnt as int)) as looseqty
   FROM PICKDETAIL PD WITH (NOLOCK)
   JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PD.orderkey
   JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PD.Storerkey AND S.SKU = PD.SKU
   JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.Packkey
   WHERE PD.Storerkey = @c_Storerkey
   AND PD.Orderkey = @c_OrderKey
   GROUP BY ORD.ExternOrderkey,PD.SKU,S.descr,S.altsku,S.busr4,P.casecnt
   ORDER BY PD.SKU   
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_ExtOrderkey,@c_SKU,@c_Sdescr,@c_altsku,@c_sbusr4,@n_pqty,@c_casecnt,@c_FullCtn,@n_looseqty
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN 
      
     SET @c_BoxNo = ''

	 --select 'start', @n_lineno '@n_lineno',@n_startcnt '@n_startcnt',@n_lastctn '@n_lastctn',@c_FullCtn '@c_FullCtn'

     IF @n_lineno = 1
     BEGIN
      SET @n_startcnt = 1
     END 
     ELSE
     BEGIN
      SET @n_startcnt = @n_lastctn + 1
     END

	 --select 'Getline', @n_lineno '@n_lineno',@n_startcnt '@n_startcnt',@n_lastctn '@n_lastctn'

     IF @c_FullCtn = 0 --AND @n_looseqty <> 0
     BEGIN
      SET @n_lastctn = @n_startcnt

      SET @c_BoxNo = CAST(@n_startcnt as nvarchar(5)) + ' - ' + CAST(@n_lastctn as nvarchar(5))
      SET @n_lastctn = @n_lastctn 

     END --@c_FullCtn = 0
     ELSE
     BEGIN
	-- SET @n_lastctn = @n_startcnt + @c_FullCtn
     IF @n_looseqty = 0
     BEGIN
        SET @n_lastctn = CASE WHEN @c_FullCtn = 1 THEN @n_startcnt ELSE (@n_startcnt + @c_FullCtn) -1 END
     END
     ELSE
     BEGIN
	   -- IF @c_FullCtn > 1
		--BEGIN
          SET @n_lastctn = CASE WHEN @c_FullCtn = 1 and @n_looseqty = 0 THEN @n_startcnt ELSE (@n_startcnt + @c_FullCtn) END
        --END
  --      ELSE
		--BEGIN
		--  SET @n_lastctn = @n_startcnt + @c_FullCtn + 1
		--END

     END

      SET @c_BoxNo = CAST(@n_startcnt as nvarchar(5)) + ' - ' + CAST(@n_lastctn as nvarchar(5))
	  --SET @n_lineno = @n_lineno + 1
     END 

     INSERT INTO #TempDELNOTES37rpt (OrderKey,ExternOrderkey,SKU,SDESCR,AltSKU,SBUSR4,PackQty,TTLPQTY,TTLCTN,CTNSKU,BoxNo,
                                     Rpttitle01,Rpttitle02,Rpttitle03,Rpttitle04,Rpttitle05,Rpttitle13,Rpttitle14,Rpttitle15 )
     VALUES(@c_OrderKey,@c_ExtOrderkey,@c_SKU,@c_Sdescr,@c_altsku,@c_sbusr4,@n_pqty,@n_ttlqty,1,
            @n_cntsku,@c_BoxNo,ISNULL(@c_Rpttitle01,''),ISNULL(@c_Rpttitle02,''),ISNULL(@c_Rpttitle03,''),
            ISNULL(@c_Rpttitle04,''),ISNULL(@c_Rpttitle05,''),
            ISNULL(@c_Rpttitle13,''),ISNULL(@c_Rpttitle14,''),ISNULL(@c_Rpttitle15,''))

       SET @n_lineno = @n_lineno + 1
         -- SET @n_startcnt = @n_startcnt + 1
       SET @n_ttlctn = @n_lastctn

   FETCH NEXT FROM CUR_RESULT INTO @c_ExtOrderkey, @c_SKU,@c_Sdescr,@c_altsku,@c_sbusr4,@n_pqty,@c_casecnt,@c_FullCtn,@n_looseqty  
   END  

   update #TempDELNOTES37rpt
   SET TTLCTN = @n_ttlctn
   WHERE OrderKey = @c_OrderKey
   
   SELECT * FROM #TempDELNOTES37rpt
   WHERE OrderKey = @c_OrderKey
   ORDER BY SKU 

END -- procedure

GO