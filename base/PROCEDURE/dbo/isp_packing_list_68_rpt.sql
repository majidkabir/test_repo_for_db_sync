SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_packing_list_68_rpt                                 */
/* Creation Date: 25-JUL-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-9963 - [CN] Erno Laszlo_Packing List                    */
/*        :                                                             */
/* Called By: r_dw_packing_list_68_rpt                                  */
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
CREATE PROC [dbo].[isp_packing_list_68_rpt]
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
         , @n_pqty            INT
         , @c_casecnt         FLOAT
         , @c_FullCtn         INT
         , @n_looseqty        INT
         , @n_Ctn             INT
         , @n_startcnt        INT
         , @n_Packqty         INT
         , @c_Storerkey       NVARCHAR(20)
       
       
   CREATE Table #TempPackList68rpt(
                 OrderKey           NVARCHAR(10) NULL 
			   , SKU                NVARCHAR(20) NULL
			   , SDESCR             NVARCHAR(120) NULL  
               , PackQty            INT 
               , CtnNo              INT  
			   , ExternOrderkey     NVARCHAR(50) NULL 
            )

   --SET @n_StartTCnt = @@TRANCOUNT
   SET @n_startcnt = 1

   SELECT TOP 1 @c_Storerkey = PD.Storerkey
   FROM PICKDETAIL PD WITH (nolock)
   WHERE PD.Orderkey = @c_OrderKey

   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   select DISTINCT ORD.ExternOrderkey,PD.SKU,S.descr,SUM(PD.QTY),P.casecnt,FLOOR(SUM(PD.qty)/P.casecnt) as ctn
   ,(SUM(PD.QTY)%cast(P.casecnt as int)) as looseqty
   FROM PICKDETAIL PD WITH (NOLOCK)
   JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PD.orderkey
   JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PD.Storerkey AND S.SKU = PD.SKU
   JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.Packkey
   WHERE PD.Storerkey = @c_Storerkey
   AND PD.Orderkey = @c_OrderKey
   GROUP BY ORD.ExternOrderkey,PD.SKU,S.descr,P.casecnt
   ORDER BY PD.SKU   
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_ExtOrderkey,@c_SKU,@c_Sdescr,@n_pqty,@c_casecnt,@c_FullCtn,@n_looseqty
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN 

   SET @n_Packqty = 1

     IF @n_startcnt = 1
     BEGIN
      IF @c_FullCtn = 0 
      BEGIN
        IF @n_looseqty <> 0 
        BEGIN
          SET @n_Packqty = @n_looseqty
          END
        ELSE
        BEGIN
          SET @n_Packqty = @c_casecnt
        END
        INSERT INTO #TempPackList68rpt (OrderKey,ExternOrderkey,SKU,SDESCR,PackQty,CtnNo )
          VALUES(@c_OrderKey,@c_ExtOrderkey,@c_SKU,@c_Sdescr,@n_Packqty,@n_startcnt)

          SET @n_startcnt = @n_startcnt + 1

      END --@c_FullCtn = 0
      ELSE
      BEGIN
         WHILE @c_FullCtn  > 0 
         BEGIN
           SET @n_Packqty = @c_casecnt

           INSERT INTO #TempPackList68rpt (OrderKey,ExternOrderkey,SKU,SDESCR,PackQty,CtnNo )
           VALUES(@c_OrderKey,@c_ExtOrderkey,@c_SKU,@c_Sdescr,@n_Packqty,@n_startcnt)

          SET @n_startcnt = @n_startcnt + 1
          SET @c_FullCtn = @c_FullCtn - 1
         END 
         
         IF @c_FullCtn = 0 AND @n_looseqty <> 0
         BEGIN
            SET @n_Packqty = @n_looseqty
            INSERT INTO #TempPackList68rpt (OrderKey,ExternOrderkey,SKU,SDESCR,PackQty,CtnNo )
            VALUES(@c_OrderKey,@c_ExtOrderkey,@c_SKU,@c_Sdescr,@n_Packqty,@n_startcnt)

            SET @n_startcnt = @n_startcnt + 1
         END 
      END--@c_FullCtn <> 0
     END  --@n_startcnt = 1
     ELSE
     BEGIN

     IF @c_FullCtn = 0 
      BEGIN
        IF @n_looseqty <> 0 
        BEGIN
          SET @n_Packqty = @n_looseqty
          END
        ELSE
        BEGIN
          SET @n_Packqty = @c_casecnt
        END
        INSERT INTO #TempPackList68rpt (OrderKey,ExternOrderkey,SKU,SDESCR,PackQty,CtnNo )
        VALUES(@c_OrderKey,@c_ExtOrderkey,@c_SKU,@c_Sdescr,@n_Packqty,@n_startcnt)

          SET @n_startcnt = @n_startcnt + 1

      END --@c_FullCtn = 0
      ELSE
      BEGIN
         WHILE @c_FullCtn  > 0 
         BEGIN
           SET @n_Packqty = @c_casecnt

           INSERT INTO #TempPackList68rpt (OrderKey,ExternOrderkey,SKU,SDESCR,PackQty,CtnNo )
           VALUES(@c_OrderKey,@c_ExtOrderkey,@c_SKU,@c_Sdescr,@n_Packqty,@n_startcnt)

           SET @n_startcnt = @n_startcnt + 1
           SET @c_FullCtn = @c_FullCtn - 1
         END 
         
         IF @c_FullCtn = 0 AND @n_looseqty <> 0
         BEGIN
            SET @n_Packqty = @n_looseqty
            INSERT INTO #TempPackList68rpt (OrderKey,ExternOrderkey,SKU,SDESCR,PackQty,CtnNo )
            VALUES(@c_OrderKey,@c_ExtOrderkey,@c_SKU,@c_Sdescr,@n_Packqty,@n_startcnt)

            SET @n_startcnt = @n_startcnt + 1
         END 
      END--@c_FullCtn <> 0
     END

   FETCH NEXT FROM CUR_RESULT INTO @c_ExtOrderkey, @c_SKU,@c_Sdescr,@n_pqty,@c_casecnt,@c_FullCtn,@n_looseqty  
   END  
   
   SELECT * FROM #TempPackList68rpt
   WHERE OrderKey = @c_OrderKey
   ORDER BY SKU,CtnNo 

END -- procedure

GO