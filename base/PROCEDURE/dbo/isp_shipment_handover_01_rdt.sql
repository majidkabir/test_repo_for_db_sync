SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_shipment_handover_01_rdt                        */
/* Creation Date: 2021-07-08                                             */
/* Copyright: IDS                                                        */
/* Written by:CSCHONG                                                    */
/*                                                                       */
/* Purpose: WMS-17303 - CN UA pre Delivery RDT1847 handover Report       */
/*                                                                       */
/* Called By: r_shipment_handover_01_rdt                                 */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 1.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author  Ver   Purposes                                    */
/*************************************************************************/
CREATE PROC [dbo].[isp_shipment_handover_01_rdt]
         (  @c_PalletID   NVARCHAR(20)   
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
         ,@c_AddWho         NVARCHAR(128)         


   SET @n_NoOfLine = 90     


  CREATE TABLE #TMPRDTPLTIDBYORD (RowNo       INT,
                              PalletID     NVARCHAR(20),
                              Orderkey    NVARCHAR(20) null, 
                              CartonType  NVARCHAR(10) null, 
                              Storerkey   NVARCHAR(20) null,
                              Trackingno  NVARCHAR(20) NULL, 
                              recgrp      INT,
                              Addwho       NVARCHAR(128) NULL)


      INSERT INTO  #TMPRDTPLTIDBYORD (RowNo,PalletID,Orderkey,Storerkey,CartonType,Trackingno,recgrp,Addwho)
      SELECT ROW_NUMBER() over(order by RTP.TrackingNo, RTP.OrderKey ) as [RowNo],
             RTP.PalletID AS PalletID,
             RTP.OrderKey AS Orderkey,
             RTP.StorerKey AS storerkey,
             RTP.CartonType AS CartonType,
             RTP.TrackingNo AS trackingno,
            (Row_Number() OVER (PARTITION BY RTP.PalletID  ORDER BY RTP.TrackingNo, RTP.OrderKey Asc)-1)/@n_NoOfLine+1 AS recgrp,
            RTP.Addwho AS Addwho  
      FROM rdt.rdtTruckPackInfo RTP WITH (NOLOCK)
      WHERE RTP.PalletID= @c_PalletID
      ORDER BY RTP.TrackingNo, RTP.OrderKey


  CREATE TABLE #TMPSPLITPLTID (
                              palletid         NVARCHAR(20),
                              TrackingNoGrp1   NVARCHAR(20) null ,
                              OrderkeyGrp1     NVARCHAR(20) null ,
                              CTNTypeGrp1      NVARCHAR(20) null ,  
                              Rownogrp1        INT null, 
                              TrackingNoGrp2   NVARCHAR(20) null,
                              OrderkeyGrp2     NVARCHAR(20) null ,
                              CTNTypeGrp2      NVARCHAR(20) null ,  
                              recgrp           INT,
                              Rownogrp2        INT NULL,
                              Storerkey        NVARCHAR(20),
                              AddWho           NVARCHAR(128)  )

declare @n_maxline        INT
       ,@n_rowno          INT
       ,@c_getPalletID    NVARCHAR(30)
       ,@c_orderkey       NVARCHAR(20)
       ,@c_Ctntype        NVARCHAR(10)
       ,@c_trackingno     NVARCHAR(20)
       ,@n_recgrp         INT
       ,@n_maxrec         INT
       ,@n_cntPLTID        INT


   SET @n_cntPLTID = 0

   SELECT @n_cntPLTID = COUNT(DISTINCT Orderkey) 
   FROM #TMPRDTPLTIDBYORD


   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT rowno,PalletID,orderkey,CartonType,Trackingno,recgrp  
                   ,ROW_NUMBER() OVER ( PARTITION BY PalletID ORDER BY rowno,PalletID,orderkey,Trackingno) 
                   ,Storerkey,Addwho
   FROM   #TMPRDTPLTIDBYORD   
   order by rowno
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @n_rowno,@c_getPalletID,@c_orderkey,@c_Ctntype,
                                   @c_trackingno,@n_recgrp,@n_recgrpsort, 
                                   @c_storerkey ,@c_AddWho      
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   

    IF @n_recgrpsort <= (@n_NoOfLine/2) 
    BEGIN
        INSERT INTO #TMPSPLITPLTID
        (
            palletid,
            CTNTypeGrp1,
            TrackingNoGrp1,
            OrderkeyGrp1,
            Rownogrp1,
            TrackingNoGrp2,
            OrderkeyGrp2,
            CTNTypeGrp2,
            recgrp,
            Rownogrp2,Storerkey,AddWho
        )
        VALUES(@c_getPalletID,@c_Ctntype,@c_trackingno,@c_Orderkey,@n_recgrpsort,'','','',@n_recgrp,'',@c_storerkey,@c_AddWho)  
    END
    ELSE IF @n_recgrpsort > (@n_NoOfLine/2) AND @n_recgrpsort <= @n_NoOfLine
    BEGIN
        UPDATE #TMPSPLITPLTID
        SET Rownogrp2 = @n_recgrpsort
           ,TrackingNoGrp2 = @c_trackingno
           ,OrderkeyGrp2 = @c_orderkey 
           ,CTNTypeGrp2 = @c_Ctntype
        WHERE palletid = @c_getPalletID
        AND recgrp = @n_recgrp
        AND Rownogrp1 = @n_recgrpsort -(@n_NoOfLine/2) 
    END
    ELSE IF @n_recgrpsort > @n_NoOfLine
    BEGIN
         set @n_maxrec = 1
         select @n_maxrec = MAX(recgrp)
         FROM   #TMPSPLITPLTID
         where  PalletID = @c_PalletID

         IF @n_recgrp =  @n_maxrec + 1 OR @n_recgrp =  @n_maxrec
         BEGIN
             --select @n_rowno%@n_maxline '@n_rowno%@n_maxline'
              IF (@n_recgrpsort%@n_NoOfLine) <= (@n_NoOfLine/2) AND (@n_recgrpsort%@n_NoOfLine) > 0
              BEGIN
                     INSERT INTO #TMPSPLITPLTID
                       (
                           palletid,
                           CTNTypeGrp1,
                           TrackingNoGrp1,
                           OrderkeyGrp1,
                           Rownogrp1,
                           TrackingNoGrp2,
                           OrderkeyGrp2,
                           CTNTypeGrp2, 
                           recgrp,
                           Rownogrp2,Storerkey,AddWho
                       )
                     VALUES(@c_getPalletID,@c_Ctntype,@c_trackingno,@c_Orderkey,@n_recgrpsort,'','','',@n_recgrp,'',@c_storerkey,@c_AddWho)  
              END
              ELSE IF (@n_recgrpsort%@n_NoOfLine) = 0 OR ((@n_recgrpsort%@n_NoOfLine) > (@n_NoOfLine/2) AND (@n_recgrpsort%@n_NoOfLine) <= @n_NoOfLine)
              BEGIN

                  UPDATE #TMPSPLITPLTID
                  SET Rownogrp2 = @n_recgrpsort
                     ,TrackingNoGrp2 = @c_trackingno
                     ,OrderkeyGrp2 = @c_orderkey 
                     ,CTNTypeGrp2 = @c_Ctntype
                 WHERE palletid = @c_getPalletID
                 AND recgrp = @n_recgrp
                   -- AND OrderkeyGrp2 = '' 
                 AND Rownogrp1 = CASE WHEN (@n_recgrpsort%@n_NoOfLine) = 0 THEN (@n_recgrpsort - @n_NoOfLine)+(@n_NoOfLine/2) 
                                       WHEN @n_recgrpsort <= 200 THEN (@n_recgrpsort%@n_NoOfLine)+(@n_NoOfLine/2) 
                                       ELSE (@n_recgrpsort%@n_NoOfLine)+((@n_NoOfLine)*(@n_recgrp-1)-(@n_NoOfLine/2)) END
              END 
         END
    END

    FETCH NEXT FROM CUR_RESULT INTO @n_rowno,@c_getPalletID,@c_orderkey,
                                  @c_Ctntype,@c_trackingno,@n_recgrp,@n_recgrpsort,
                                  @c_storerkey,@c_AddWho     
   END   

  CLOSE CUR_RESULT
  DEALLOCATE CUR_RESULT

    

    SELECT palletid as palletid,
           CtnTypeGrp1 AS CtnTypeGrp1,
           OrderkeyGrp1 as OrderkeyGrp1,
           TrackingNoGrp1 AS TrackingNoGrp1,
           recgrp as recgrp,
           CASE WHEN ISNULL(OrderkeyGrp2,'') <> '' THEN CAST(rownogrp2 as NVARCHAR(10) ) ELSE '' END AS rownogrp2,
           CAST(rownogrp1 as NVARCHAR(10) ) AS rownogrp1,
           OrderkeyGrp2 as OrderkeyGrp2, 
           TrackingNoGrp2 AS TrackingNoGrp2,                      
           @n_cntPLTID AS cntPLTID,
           Storerkey AS storerkey,
           CTNTypeGrp2 AS  CTNTypeGrp2,
           AddWho AS Addwho
    FROM  #TMPSPLITPLTID


drop table #TMPRDTPLTIDBYORD
drop table #TMPSPLITPLTID

QUIT_SP:
END


GO