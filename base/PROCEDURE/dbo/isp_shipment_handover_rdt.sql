SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_shipment_handover_rdt                           */
/* Creation Date: 2021-05-18                                             */
/* Copyright: IDS                                                        */
/* Written by:CSCHONG                                                    */
/*                                                                       */
/* Purpose: WMS-16998 WMS-16999 - carrier MBOL handover paper list CR    */
/*                                                                       */
/* Called By: r_shipment_handover_rdt                                    */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 1.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author  Ver   Purposes                                    */
/* 09-Jun-2021 CSCHONG 1.1   WMS-16998 show 45 per page issue (CS01)     */
/*************************************************************************/
CREATE PROC [dbo].[isp_shipment_handover_rdt]
         (  @c_externmbolkey   NVARCHAR(30)   
          )  

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE --@c_storerkey  NVARCHAR(10)
          @c_storerkey      NVARCHAR(10) 
         ,@n_NoOfLine       INT
         ,@n_recgrpsort     INT          


   SET @n_NoOfLine = 90     --CS01


  CREATE TABLE #TMPMBOLBYORD (RowNo       INT,
                              mbolkey     NVARCHAR(20),
                              Orderkey    NVARCHAR(20) null, 
                              ExtMbolkey  NVARCHAR(30) null, 
                              Storerkey   NVARCHAR(20) null,
                              ExtOrdkey   NVARCHAR(50) NULL,
                              Trackingno  NVARCHAR(20) NULL, 
                              recgrp      INT)


      INSERT INTO  #TMPMBOLBYORD (RowNo,mbolkey,ExtMbolkey,Orderkey,Storerkey,ExtOrdkey,Trackingno,recgrp)
      SELECT ROW_NUMBER() over(order by  OH.OrderKey, OH.ExternOrderKey ) as [RowNo],
             MB.MbolKey AS mbolkey,
             MB.ExternMbolKey AS ExternMbolkey ,
             OH.OrderKey AS Orderkey,
             OH.StorerKey AS storerkey,
             OH.ExternOrderKey AS Externorderkey,
             OH.TrackingNo AS trackingno,
            (Row_Number() OVER (PARTITION BY MB.MbolKey  ORDER BY OH.OrderKey, OH.ExternOrderKey Asc)-1)/@n_NoOfLine+1 AS recgrp
      FROM MBOL MB WITH (NOLOCK)
      JOIN ORDERS OH WITH (NOLOCK) ON OH.mbolKey=MB.mbolKey
      WHERE MB.ExternMbolKey= @c_externmbolkey
      ORDER BY OH.OrderKey, OH.ExternOrderKey    --CS01


  CREATE TABLE #TMPSPLITMBOL (
                              mbolkey          NVARCHAR(20),
                              ExtMbolkey       NVARCHAR(30), 
                              TrackingNoGrp1   NVARCHAR(20) null ,
                              ExtOrderkeyGrp1  NVARCHAR(20) null ,
                              Rownogrp1        INT null, 
                              TrackingNoGrp2   NVARCHAR(20) null,
                              ExtOrderkeyGrp2  NVARCHAR(20) null ,
                              recgrp           INT,
                              Rownogrp2        INT NULL,
                              Storerkey        NVARCHAR(20) )

declare @n_maxline        INT
       ,@n_rowno          INT
       ,@c_mbolkey        NVARCHAR(20)
       ,@c_getExtmbolkey  NVARCHAR(30)
       ,@c_orderkey       NVARCHAR(20)
       ,@c_extOrdkey      NVARCHAR(50)
       ,@c_trackingno     NVARCHAR(20)
       ,@n_recgrp         INT
       ,@n_maxrec         INT
       ,@n_cntLabelno     INT


   SET @n_cntLabelno = 0

   SELECT @n_cntLabelno = COUNT(DISTINCT PD.labelno) 
   FROM PACKHEADER PH (NOLOCK)
   JOIN packdetail PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
   JOIN #TMPMBOLBYORD TPO ON TPO.Orderkey = PH.OrderKey

   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT rowno,mbolkey,orderkey,ExtMbolkey,ExtOrdkey,Trackingno,recgrp  
                   ,ROW_NUMBER() OVER ( PARTITION BY mbolkey ORDER BY rowno,mbolkey,orderkey,ExtOrdkey) 
                   ,Storerkey
   FROM   #TMPMBOLBYORD   
   order by rowno
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @n_rowno,@c_mbolkey,@c_orderkey,@c_getextmbolkey,
                                  @c_extOrdkey,@c_trackingno,@n_recgrp,@n_recgrpsort, 
                                  @c_storerkey       
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   

    IF @n_recgrpsort <= (@n_NoOfLine/2) 
    BEGIN
        INSERT INTO #TMPSPLITMBOL
        (
            mbolkey,
            ExtMbolkey,
            TrackingNoGrp1,
            ExtOrderkeyGrp1,
            Rownogrp1,
            TrackingNoGrp2,
            ExtOrderkeyGrp2,
            recgrp,
            Rownogrp2,Storerkey
        )
        VALUES(@c_mbolkey,@c_getextmbolkey,@c_trackingno,@c_extOrdkey,@n_recgrpsort,'','',@n_recgrp,'',@c_storerkey)  
    END
    ELSE IF @n_recgrpsort > (@n_NoOfLine/2) AND @n_recgrpsort <= @n_NoOfLine
    BEGIN
        UPDATE #TMPSPLITMBOL
        SET Rownogrp2 = @n_recgrpsort
           ,TrackingNoGrp2 = @c_trackingno
           ,ExtOrderkeyGrp2 = @c_extOrdkey
        WHERE mbolkey = @c_mbolkey
        AND ExtMbolkey=@c_getExtmbolkey
        AND recgrp = @n_recgrp
        AND Rownogrp1 = @n_recgrpsort -(@n_NoOfLine/2) 
    END
    ELSE IF @n_recgrpsort > @n_NoOfLine
    BEGIN
         set @n_maxrec = 1
         select @n_maxrec = MAX(recgrp)
         FROM   #TMPSPLITMBOL
         where  mbolkey = @c_mbolkey
        AND ExtMbolkey=@c_getExtmbolkey

         IF @n_recgrp =  @n_maxrec + 1 OR @n_recgrp =  @n_maxrec
         BEGIN
             --select @n_rowno%@n_maxline '@n_rowno%@n_maxline'
              IF (@n_recgrpsort%@n_NoOfLine) <= (@n_NoOfLine/2) AND (@n_recgrpsort%@n_NoOfLine) > 0
              BEGIN
                     INSERT INTO #TMPSPLITMBOL
                       (
                           mbolkey,
                           ExtMbolkey,
                           TrackingNoGrp1,
                           ExtOrderkeyGrp1,
                           Rownogrp1,
                           TrackingNoGrp2,
                           ExtOrderkeyGrp2,
                           recgrp,
                           Rownogrp2,Storerkey
                       )
                     VALUES(@c_mbolkey,@c_getextmbolkey,@c_trackingno,@c_extOrdkey,@n_recgrpsort,'','',@n_recgrp,'',@c_storerkey)  
              END
              ELSE IF (@n_recgrpsort%@n_NoOfLine) = 0 OR ((@n_recgrpsort%@n_NoOfLine) > (@n_NoOfLine/2) AND (@n_recgrpsort%@n_NoOfLine) <= @n_NoOfLine)
              BEGIN

                  UPDATE #TMPSPLITMBOL
                  SET Rownogrp2 = @n_recgrpsort
                     ,TrackingNoGrp2 = @c_trackingno
                     ,ExtOrderkeyGrp2 = @c_extOrdkey
                 WHERE mbolkey = @c_mbolkey
                 AND ExtMbolkey=@c_getExtmbolkey
                 AND recgrp = @n_recgrp
                   -- AND OrderkeyGrp2 = '' 
                 AND Rownogrp1 = CASE WHEN (@n_recgrpsort%@n_NoOfLine) = 0 THEN (@n_recgrpsort - @n_NoOfLine)+(@n_NoOfLine/2) 
                                       WHEN @n_recgrpsort <= 200 THEN (@n_recgrpsort%@n_NoOfLine)+(@n_NoOfLine/2) 
                                       ELSE (@n_recgrpsort%@n_NoOfLine)+((@n_NoOfLine)*(@n_recgrp-1)-(@n_NoOfLine/2)) END
              END 
         END
    END

    FETCH NEXT FROM CUR_RESULT INTO @n_rowno,@c_mbolkey,@c_orderkey,@c_getextmbolkey,
                                  @c_extOrdkey,@c_trackingno,@n_recgrp,@n_recgrpsort,
                                  @c_storerkey
   END   

  CLOSE CUR_RESULT
  DEALLOCATE CUR_RESULT

    

    SELECT mbolkey as mbolkey,
           ExtMbolkey AS Extmbolkey,
           ExtOrderkeyGrp1 as ExtOrderkeyGrp1,
           TrackingNoGrp1 AS TrackingNoGrp1,
           recgrp as recgrp,
           CASE WHEN ISNULL(ExtOrderkeyGrp2,'') <> '' THEN CAST(rownogrp2 as NVARCHAR(10) ) ELSE '' END AS rownogrp2,
           CAST(rownogrp1 as NVARCHAR(10) ) AS rownogrp1,
           ExtOrderkeyGrp2 as ExtOrderkeyGrp2, 
           TrackingNoGrp2 AS TrackingNoGrp2,                      
           @n_cntLabelno AS CntLabelNo,
           Storerkey AS storerkey 
    FROM  #TMPSPLITMBOL


drop table #TMPMBOLBYORD
drop table #TMPSPLITMBOL

QUIT_SP:
END


GO